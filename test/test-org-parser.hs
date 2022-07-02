-- |

module Main
 ( module Main
 , module Tests.Helpers
 , module Org.Parser.Document
 , module Org.Parser.Elements
 , module Org.Parser.Objects
 ) where

import Test.Tasty
import Tests.Helpers
import Tests.Document
import Tests.Objects
import Tests.Elements
import Org.Parser.Document
import Org.Parser.Elements
import Org.Parser.Objects

tests :: TestTree
tests = testGroup "Org parser tests"
        [ testObjects
        , testElements
        , testDocument
        ]

main :: IO ()
main = do
  defaultMain tests
