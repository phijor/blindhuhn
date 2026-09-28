module Main where

open import Agda.Builtin.Bool

named : Bool → Bool
named = λ where
  true → false
  false → true
