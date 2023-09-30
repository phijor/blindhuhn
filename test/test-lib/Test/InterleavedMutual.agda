module Test.InterleavedMutual where

open import Agda.Builtin.Nat

interleaved mutual

  -- Declaration of a product record, a universe of codes, and a decoding function
  record _×_ (A B : Set) : Set
  data U : Set
  El : U → Set

  -- We have a code for the type of natural numbers in our universe
  data U where `Nat : U
  El `Nat = Nat

  -- Btw we know how to pair values in a record
  record _×_ A B where
    inductive; constructor _,_
    field fst : A; snd : B

  -- And we have a code for pairs in our universe
  data _ where
    _`×_ : (A B : U) → U
  El (A `× B) = El A × El B

-- we can now build types of nested pairs of natural numbers
ty-example : U
ty-example = `Nat `× ((`Nat `× `Nat) `× `Nat)

-- and their values
val-example : El ty-example
val-example = 0 , ((1 , 2) , 3)
