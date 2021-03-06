module Grammar.Greek.Script.Rounds.Accent where

import Control.Lens (over, _1)
import Data.Either.Validation
import Grammar.Common.List
import Grammar.Common.Round
import Grammar.Common.Types
import Grammar.Greek.Script.Types
import Grammar.Greek.Script.Word

data InvalidContextualAccent = InvalidContextualAccent ([Int :* ContextualAccent] :* HasWordPunctuation)
  deriving (Show)

data InvalidWordAccent = InvalidWordAccent (Maybe WordAccent :* HasWordPunctuation)
  deriving (Show)

pattern StandardAccent :: BasicAccent -> AccentPosition -> Maybe WordAccent
pattern StandardAccent a p = Just (WordAccent a p NoForceAcute NoExtraAccents)
pattern ExtraAcuteUlt :: BasicAccent -> AccentPosition -> Maybe WordAccent
pattern ExtraAcuteUlt a p = Just (WordAccent a p NoForceAcute ExtraAcuteUltima)
pattern ExtraAcutePen :: BasicAccent -> AccentPosition -> Maybe WordAccent
pattern ExtraAcutePen a p = Just (WordAccent a p NoForceAcute ExtraAcutePenult)
pattern ForceAccent :: BasicAccent -> AccentPosition -> Maybe WordAccent
pattern ForceAccent a p = Just (WordAccent a p DoForceAcute NoExtraAccents)

accent :: Round InvalidContextualAccent InvalidWordAccent
  ([s :* Maybe ContextualAccent] :* HasWordPunctuation)
  ([s] :* Maybe WordAccent :* HasWordPunctuation)
accent = Round (over _Failure pure . to) (over _Failure pure . from)
  where
  to (ss, hp) = (\a -> (fmap fst ss, (a, hp))) <$> acc
    where
    acc = toPair (onlyAccentsWithReverseIndex $ getAccents ss, hp)

  toPair ([], _) = Success Nothing
  toPair ([(0,AC_Acute)], HasWordPunctuation) = Success $ StandardAccent AB_Acute Ultima
  toPair ([(0,AC_Acute)], NoWordPunctuation) = Success $ ForceAccent AB_Acute Ultima
  toPair ([(0,AC_Grave)], NoWordPunctuation) = Success $ StandardAccent AB_Acute Ultima
  toPair ([(0,AC_Circumflex)], _) = Success $ StandardAccent AB_Circumflex Ultima
  toPair ([(1,AC_Acute)], _) = Success $ StandardAccent AB_Acute Penult
  toPair ([(1,AC_Acute),(0,AC_Acute)], NoWordPunctuation) = Success $ ExtraAcuteUlt AB_Acute Penult
  toPair ([(1,AC_Circumflex)], _) = Success $ StandardAccent AB_Circumflex Penult
  toPair ([(1,AC_Circumflex),(0,AC_Acute)], NoWordPunctuation) = Success $ ExtraAcuteUlt AB_Circumflex Penult
  toPair ([(2,AC_Circumflex),(0,AC_Acute)], NoWordPunctuation) = Success $ ExtraAcuteUlt AB_Circumflex Antepenult
  toPair ([(2,AC_Circumflex),(1,AC_Acute)], _) = Success $ ExtraAcutePen AB_Circumflex Antepenult
  toPair ([(2,AC_Circumflex)], _) = Success $ StandardAccent AB_Circumflex Antepenult
  toPair ([(2,AC_Acute)], _) = Success $ StandardAccent AB_Acute Antepenult
  toPair ([(2,AC_Acute),(0,AC_Acute)], NoWordPunctuation) = Success $ ExtraAcuteUlt AB_Acute Antepenult
  toPair ([(3,AC_Acute),(1,AC_Acute)], _) = Success $ ExtraAcutePen AB_Acute Preantepenult
  toPair x = Failure $ InvalidContextualAccent x

  from = over (_Success . _1) reverse . fromTriple . over _1 (reverse . fmap (\x -> (x, Nothing)))

  fromTriple (xs, (Nothing, hp)) = Success (xs, hp)
  fromTriple ((s, _) : xs, (StandardAccent AB_Acute Ultima, hp@HasWordPunctuation)) = Success ((s, Just AC_Acute) : xs, hp)
  fromTriple ((s, _) : xs, (ForceAccent AB_Acute Ultima, hp@NoWordPunctuation)) = Success ((s, Just AC_Acute) : xs, hp)
  fromTriple ((s, _) : xs, (StandardAccent AB_Acute Ultima, hp@NoWordPunctuation)) = Success ((s, Just AC_Grave) : xs, hp)
  fromTriple ((s, _) : xs, (StandardAccent AB_Circumflex Ultima, hp)) = Success ((s, Just AC_Circumflex) : xs, hp)
  fromTriple (x1 : (s2, _) : xs, (StandardAccent AB_Acute Penult, hp)) = Success (x1 : (s2, Just AC_Acute) : xs, hp)
  fromTriple ((s1, _) : (s2, _) : xs, (ExtraAcuteUlt AB_Acute Penult, hp@NoWordPunctuation)) = Success ((s1, Just AC_Acute) : (s2, Just AC_Acute) : xs, hp)
  fromTriple (x1 : (s2, _) : xs, (StandardAccent AB_Circumflex Penult, hp)) = Success (x1 : (s2, Just AC_Circumflex) : xs, hp)
  fromTriple ((s1, _) : (s2, _) : xs, (ExtraAcuteUlt AB_Circumflex Penult, hp@NoWordPunctuation)) = Success ((s1, Just AC_Acute) : (s2, Just AC_Circumflex) : xs, hp)
  fromTriple (x1 : x2 : (s3, _) : xs, (StandardAccent AB_Acute Antepenult, hp)) = Success (x1 : x2 : (s3, Just AC_Acute) : xs, hp)
  fromTriple (x1 : x2 : (s3, _) : xs, (StandardAccent AB_Circumflex Antepenult, hp)) = Success (x1 : x2 : (s3, Just AC_Circumflex) : xs, hp)
  fromTriple ((s1, _) : x2 : (s3, _) : xs, (ExtraAcuteUlt AB_Acute Antepenult, hp@NoWordPunctuation)) = Success ((s1, Just AC_Acute) : x2 : (s3, Just AC_Acute) : xs, hp)
  fromTriple ((s1, _) : x2 : (s3, _) : xs, (ExtraAcuteUlt AB_Circumflex Antepenult, hp)) = Success ((s1, Just AC_Acute) : x2 : (s3, Just AC_Circumflex) : xs, hp)
  fromTriple (x1 : (s2, _) : (s3, _) : xs, (ExtraAcutePen AB_Circumflex Antepenult, hp)) = Success (x1 : (s2, Just AC_Acute) : (s3, Just AC_Circumflex) : xs, hp)
  fromTriple (x1 : (s2, _) : x3 : (s4, _) : xs, (ExtraAcutePen AB_Acute Preantepenult, hp)) = Success (x1 : (s2, Just AC_Acute) : x3 : (s4, Just AC_Acute) : xs, hp)
  fromTriple (_, x) = Failure $ InvalidWordAccent x

getAccents :: [ s :* Maybe ContextualAccent ] -> [Maybe ContextualAccent]
getAccents = over traverse snd

onlyAccentsWithReverseIndex :: [Maybe ContextualAccent] -> [(Int, ContextualAccent)]
onlyAccentsWithReverseIndex = onlyAccents . addReverseIndex
  where
  onlyAccents :: [(Int, Maybe ContextualAccent)] -> [(Int, ContextualAccent)]
  onlyAccents = concatMap go
    where
    go (i, Just x) = [(i, x)]
    go _ = []
