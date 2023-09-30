module Test.Lambda where

open import Agda.Builtin.Nat

infixl 5 _,_
infix 4 _∋_
infix 4 _⊢_
infixr 7 _⇒_
infixl 7 _$_

data Type : Set where
  _⇒_ : Type → Type → Type
  ℕ : Type

data Context : Set where
  ∅ : Context
  _,_ : (Γ : Context) → (A : Type) → Context

data _∋_ : (Γ : Context) (A : Type) → Set where
  here : ∀ {Γ A}
    -----------
    → Γ , A ∋ A

  there : ∀ {Γ A B}
    → Γ ∋ A
    -----------
    → Γ , B ∋ A

data _⊢_ : (Γ : Context) (A : Type) → Set where
  ax : ∀ {Γ A}
    → Γ ∋ A
    -------
    → Γ ⊢ A

  lam : ∀ {Γ A B}
    → Γ , A ⊢ B
    -----------
    → Γ ⊢ A ⇒ B

  _$_ : ∀ {Γ A B}
    → Γ ⊢ A ⇒ B
    → Γ ⊢ A
    -----------
    → Γ ⊢ B

  zero : ∀ {Γ}
    -------
    → Γ ⊢ ℕ

  suc : ∀ {Γ}
    → Γ ⊢ ℕ
    -------
    → Γ ⊢ ℕ

  rec : ∀ {Γ A}
    → (n : Γ ⊢ ℕ)
    → (zero* : Γ ⊢ A)
    → (suc* : Γ , ℕ ⊢ A)
    --------------------
    → Γ ⊢ A

  μ : ∀ {Γ A}
    → Γ , A ⊢ A
    -----------
    → Γ ⊢ A

id : ∀ {Γ A} → Γ ⊢ A ⇒ A
id = lam (ax here)

length : Context → Nat
length ∅ = 0
length (Γ , _) = suc (length Γ)
