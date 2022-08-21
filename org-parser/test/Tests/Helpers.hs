{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

-- |
module Tests.Helpers
  ( module Tests.Helpers,
    module Test.Tasty,
  )
where

import Data.Algorithm.DiffContext (getContextDiff, prettyContextDiff)
import Org.Builder (Many)
import Org.Parser.Definitions
import Test.Tasty
import Test.Tasty.HUnit
import Text.Pretty.Simple
import Text.PrettyPrint (render, text)

-- | This class is mainly used for the tests cases.
-- @Parsed m a@ is the "monad-stripped" version of parse
-- tree with which we can compare in the test cases.
class Parsable m a where
  type Parsed m a
  parse' :: m a -> Text -> Either OrgParseError (Parsed m a)

applyFuture :: (F a, OrgParserState) -> a
applyFuture = uncurry (runReader . getAp)

instance Parsable OrgParser (F a) where
  type Parsed OrgParser (F a) = a
  parse' p =
    second applyFuture
      . parse (runStateT p defaultState <* eof) ""

instance Parsable (Marked OrgParser) (F a) where
  type Parsed (Marked OrgParser) (F a) = a
  parse' p = parse' (getParser p)

instance Parsable OrgParser Properties where
  type Parsed OrgParser Properties = Properties
  parse' p = parse (evalStateT p defaultState <* eof) ""

instance PrettyFormable Properties where
  type PrettyForm Properties = Properties
  prettyForm = id

instance Parsable OrgParser OrgDocument where
  type Parsed OrgParser OrgDocument = OrgDocument
  parse' p = parse (evalStateT p defaultState <* eof) ""

instance PrettyFormable OrgDocument where
  type PrettyForm OrgDocument = OrgDocument
  prettyForm = id

class PrettyFormable a where
  type PrettyForm a
  prettyForm :: a -> PrettyForm a

instance PrettyFormable (Many a) where
  type PrettyForm (Many a) = [a]
  prettyForm = toList

prettyParse :: (Parsable m a, PrettyFormable (Parsed m a), Show (PrettyForm (Parsed m a))) => m a -> Text -> IO ()
prettyParse parser txt =
  case parse' parser txt of
    Left e -> putStrLn $ errorBundlePretty e
    Right x -> pPrint $ prettyForm x

infix 1 =?>

(=?>) :: a -> b -> (a, Either () b)
x =?> y = (x, Right y)

infix 1 =!>

(=!>) :: a -> () -> (a, Either () c)
x =!> y = (x, Left y)

infix 4 =:

(=:) :: (Eq a, Show a) => TestName -> (a, a) -> TestTree
(=:) name (x, y) = testCase name (x @?= y)

infix 4 ~:

(~:) ::
  (Parsable m a, PrettyFormable (Parsed m a), Eq (Parsed m a), Show (Parsed m a)) =>
  TestName ->
  m a ->
  [(Text, Either () (Parsed m a))] ->
  TestTree
(~:) name parser cases =
  testGroup name $
    flip (`zipWith` [0 ..]) cases $ \(i :: Int) (txt, ref) ->
      testCase (name <> " " <> show i) $
        case parse' parser txt of
          Left e
            | isRight ref -> assertFailure $ errorBundlePretty e
            | otherwise -> pure ()
          Right x
            | Right ref' <- ref ->
              unless (x == ref') do
                let reflines = map toString $ lines (toStrict $ pShow ref')
                    gotlines = map toString $ lines (toStrict $ pShow x)
                    diff = getContextDiff 3 reflines gotlines
                    pdiff = prettyContextDiff (text "Test reference") (text "Parsed") text diff
                assertFailure (render pdiff)
            | otherwise ->
              assertFailure $
                "Should not parse, but parsed as:\n" <> show x
