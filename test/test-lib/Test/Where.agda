module Test.Where where

open import Agda.Builtin.Unit

private
  top-level-private = tt

module _ where
  anonymous-visible = tt

module NamedModule where
  visible = tt

top-level : ⊤
top-level = where-invisible where
  where-invisible = tt

top-level2 : ⊤
top-level2 = where-invisible where
  where-invisible = tt
