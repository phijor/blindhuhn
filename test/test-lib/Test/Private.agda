module Test.Private where

open import Agda.Builtin.Nat

private
  priavte-def : Nat
  priavte-def = 42

public-def : Nat
public-def = priavte-def
