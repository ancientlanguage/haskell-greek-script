{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

module ScriptQueries where

import Prelude hiding (Word)
import Control.Lens (over, _1, _2, _Left, toListOf, view, _Just)
import Data.Map (Map)
import qualified Data.Map as Map
import qualified Data.List as List

import Grammar.IO.QueryStage
import Grammar.Common.List
import qualified Grammar.Common.Prepare as Prepare
import Grammar.Common.Round
import Grammar.Common.Types
import qualified Grammar.Greek.Script.Stage as Stage
import Grammar.Greek.Script.Types
import Grammar.Greek.Script.Word
import qualified Primary

queryElision = pure . view (_2 . _1 . _2)

queryLetterMarks
  :: ctx :* ((([Letter :* [Mark]] :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [Letter :* [Mark]]
queryLetterMarks = view (_2 . _1 . _1 . _1)

queryMarks
  :: ctx :* ((([Letter :* [Mark]] :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [[Mark]]
queryMarks = over traverse snd . fst . fst . fst . snd

queryLetterSyllabicMark
  :: ctx :* ((([Letter :* Maybe ContextualAccent :* Maybe Breathing :* Maybe SyllabicMark] :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [Letter :* Maybe SyllabicMark]
queryLetterSyllabicMark = over traverse (\(l, (_, (_, sm))) -> (l, sm)) . fst . fst . fst . snd

queryVowelMarks
  :: ctx
    :* ((([ (Vowel :* Maybe ContextualAccent :* Maybe Breathing :* Maybe SyllabicMark) :+ ConsonantRho ]
      :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [Vowel :* Maybe ContextualAccent :* Maybe Breathing :* Maybe SyllabicMark]
queryVowelMarks = toListOf (_2 . _1 . _1 . _1 . traverse . _Left)

queryVocalicSyllable
  :: ctx
    :* ((([ [VocalicSyllable :* Maybe ContextualAccent :* Maybe Breathing] :+ [ConsonantRho] ]
     :* DiaeresisConvention :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [[VocalicSyllable]]
queryVocalicSyllable = over (traverse . traverse) (view _1) . toListOf (_2 . _1 . _1 . _1 . traverse . _Left)

queryVowelMarkGroups
  :: ctx
    :* ((([ [Vowel :* Maybe ContextualAccent :* Maybe Breathing :* Maybe SyllabicMark]
      :+ [ConsonantRho]
      ]
      :* Capitalization) :* Elision) :* HasWordPunctuation)
  -> [[Vowel :* Maybe ContextualAccent :* Maybe Breathing :* Maybe SyllabicMark]]
queryVowelMarkGroups = toListOf (_2 . _1 . _1 . _1 . traverse . _Left)

queryCrasis
  :: ctx :* a :* b :* c :* Crasis :* d
  -> [Crasis]
queryCrasis = toListOf (_2 . _2 . _2 . _2 . _1)

queryMarkPreservation
  :: ctx :* a :* b :* MarkPreservation :* c
  -> [MarkPreservation]
queryMarkPreservation = toListOf (_2 . _2 . _2 . _1)

toAccentReverseIndex :: [Maybe ContextualAccent] -> [(Int, ContextualAccent)]
toAccentReverseIndex = onlyAccents . addReverseIndex
  where
  onlyAccents :: [(Int, Maybe ContextualAccent)] -> [(Int, ContextualAccent)]
  onlyAccents = concatMap go
    where
    go (i, Just x) = [(i, x)]
    go _ = []

queryAccentReverseIndexPunctuation
  :: ctx :* ([ ([ConsonantRho] :* VocalicSyllable) :* Maybe ContextualAccent ] :* HasWordPunctuation)
    :* [ConsonantRho] :* MarkPreservation :* Crasis :* InitialAspiration :* DiaeresisConvention :* Capitalization :* Elision
  -> [[Int :* ContextualAccent] :* HasWordPunctuation]
queryAccentReverseIndexPunctuation = pure . over _1 goAll . getPair
  where
  goAll = toAccentReverseIndex . getAccents

  getPair
    :: m :* ([ a :* Maybe ContextualAccent ] :* HasWordPunctuation) :* b
    -> [ a :* Maybe ContextualAccent ] :* HasWordPunctuation
  getPair x = (view (_2 . _1 . _1) x, view (_2 . _1 . _2) x)

  getAccents :: [ a :* Maybe ContextualAccent ] -> [Maybe ContextualAccent]
  getAccents = over traverse snd

queryAccentReverseIndex
  :: ctx :* ([ ([ConsonantRho] :* VocalicSyllable) :* Maybe ContextualAccent ] :* a) :* b
  -> [[Int :* ContextualAccent]]
queryAccentReverseIndex = pure . toAccentReverseIndex . fmap snd . view (_2 . _1 . _1)

queryFinalConsonants
  :: ctx :* Word
  -> [[ConsonantRho]]
queryFinalConsonants = pure . view (_2 . _wordFinalConsonants)

queryElisionSyllables
  :: ctx :* Word
  -> [InitialAspiration :* [Syllable] :* [ConsonantRho]]
queryElisionSyllables = result
  where
  result x = case el x of
    IsElided -> [(asp x, (syll x, fin x))]
    Aphaeresis -> []
    NotElided -> []
  asp = view (_2 . _wordInitialAspiration)
  syll = view (_2 . _wordSyllables)
  fin = view (_2 . _wordFinalConsonants)
  el = view (_2 . _wordElision)

queryFinalSyllable
  :: ctx :* Word
  -> [[Syllable] :* [ConsonantRho]]
queryFinalSyllable = result
  where
  result x = pure (syll x, fin x)
  syll = reverse . List.take 1 . reverse . view (_2 . _wordSyllables)
  fin = view (_2 . _wordFinalConsonants)

queryIndependentSyllables :: ctx :* Word -> [Syllable]
queryIndependentSyllables = toListOf (_2 . _wordSyllables . traverse)

getInitialSyllable :: Word -> InitialAspiration :* [Syllable]
getInitialSyllable w = (wordInitialAspiration w, take 1 . wordSyllables $ w)

getFinalSyllable :: Word -> [Syllable] :* [ConsonantRho]
getFinalSyllable w = (take 1 . reverse . wordSyllables $ w, wordFinalConsonants w)

uncurrySyllable :: Syllable -> [ConsonantRho] :* VocalicSyllable
uncurrySyllable (Syllable c v) = (c, v)

getInitialVocalicSyllable :: Word -> [InitialAspiration :* VocalicSyllable]
getInitialVocalicSyllable w = result
  where
  result = case ss of
    (Syllable [] v : _) -> pure (asp, v)
    _ -> []
  (asp, ss) = getInitialSyllable w

queryElisionNextSyllable
  :: (ctx :* Word) :* [ctx :* Word] :* [ctx :* Word]
  -> [[[ConsonantRho] :* VocalicSyllable] :* [ConsonantRho] :* [InitialAspiration :* [VocalicSyllable]]]
queryElisionNextSyllable (w, (_, nws)) = ens
  where
  ens = case view (_2 . _wordElision) w of
    IsElided -> pure (fmap uncurrySyllable . snd . getInitialSyllable $ snd w, (fc, mn))
    Aphaeresis -> []
    NotElided -> []
  fc = view (_2 . _wordFinalConsonants) w
  mn = case nws of
    [] -> []
    (nw : _) -> pure (view (_2 . _wordInitialAspiration) nw, fmap (snd . uncurrySyllable) . take 1 . view (_2 . _wordSyllables) $ nw)

queryDeNext
  :: (ctx :* Word) :* [ctx :* Word] :* [ctx :* Word]
  -> [() :* [InitialAspiration :* VocalicSyllable]]
queryDeNext (w, (_, n)) =
  case wordSyllables (snd w) of
    [Syllable [CR_δ] (VS_Vowel V_ε)] -> pure ((), concatMap (getInitialVocalicSyllable . snd) . take 1 $ n)
    _ -> []

queryStage
  :: (Show e1, Ord c, Show c)
  => Round
  (MilestoneCtx :* e1)
    e2
    [MilestoneCtx :* (String :* HasWordPunctuation)]
    [b]
  -> (b -> [c])
  -> QueryOptions
  -> [Primary.Group]
  -> IO ()
queryStage a f = queryStageContext 0 a (f . fst)

queryStageContext
  :: (Show e1, Ord c, Show c)
  => Int
  -> Round
    (MilestoneCtx :* e1)
    e2
    [MilestoneCtx :* (String :* HasWordPunctuation)]
    [b]
  -> (b :* [b] :* [b] -> [c])
  -> QueryOptions
  -> [Primary.Group]
  -> IO ()
queryStageContext contextSize stg itemQuery qo gs = queryStageWithContext contextSize stg itemQuery qo Stage.basicWord Stage.fullWordText Stage.forgetHasWordPunctuation $ Prepare.prepareGroups gs

queryFinalConsonantNoElision
  :: ctx :* Word
  -> [[ConsonantRho]]
queryFinalConsonantNoElision (_, w) = result
  where
  result = case (el, fc) of
    (NotElided, _ : _) -> pure fc
    _ -> []
  el = wordElision w
  fc = wordFinalConsonants w

queryWordBasicAccent :: ctx :* Word -> [[BasicAccent]]
queryWordBasicAccent (_, w) = [toListOf (_wordAccent . _Just . _accentValue) w]

queryWordExtraAccent :: ctx :* Word -> [[ExtraAccents]]
queryWordExtraAccent (_, w) = [toListOf (_wordAccent . _Just . _accentExtra) w]

queryWordAccentPosition :: ctx :* Word -> [[AccentPosition]]
queryWordAccentPosition (_, w) = [toListOf (_wordAccent . _Just . _accentPosition) w]

queryWordForceAcute :: ctx :* Word -> [ForceAcute]
queryWordForceAcute = toListOf (_2 . _wordAccent . _Just . _accentForce)

queryWordAccentWithPosition :: ctx :* Word -> [Maybe (BasicAccent :* AccentPosition)]
queryWordAccentWithPosition = pure . over _Just (\x -> (accentValue x, accentPosition x)) . view (_2 . _wordAccent)

queryWordInitialAspiration :: ctx :* Word -> [InitialAspiration]
queryWordInitialAspiration (_, w) = toListOf (_wordInitialAspiration) w

queryWordDiaeresisConvention :: ctx :* Word -> [DiaeresisConvention]
queryWordDiaeresisConvention (_, w) = toListOf _wordDiaeresisConvention w

queries :: Map String (QueryOptions -> [Primary.Group] -> IO ())
queries = Map.fromList
  [ ("elision", queryStage Stage.toElision queryElision)
  , ("letter-marks", queryStage Stage.toMarkGroups queryLetterMarks)
  , ("marks", queryStage Stage.toMarkGroups queryMarks)
  , ("letter-syllabic-mark", queryStage Stage.toMarkSplit queryLetterSyllabicMark)
  , ("vocalic-syllable", queryStage Stage.toVocalicSyllable queryVocalicSyllable)
  , ("vowel-marks", queryStage Stage.toConsonantMarks queryVowelMarks)
  , ("vowel-mark-groups", queryStage Stage.toGroupVowelConsonants queryVowelMarkGroups)
  , ("crasis", queryStage Stage.toBreathing queryCrasis)
  , ("mark-preservation", queryStage Stage.toBreathing queryMarkPreservation)
  , ("accent-reverse-index", queryStage Stage.toBreathing queryAccentReverseIndex)
  , ("accent-reverse-index-punctuation", queryStage Stage.toBreathing queryAccentReverseIndexPunctuation)
  , ("final-consonants", queryStage Stage.script queryFinalConsonants)
  , ("elision-syllables", queryStage Stage.script queryElisionSyllables)
  , ("final-syllable", queryStage Stage.script queryFinalSyllable)
  , ("independent-syllables", queryStage Stage.script queryIndependentSyllables)
  , ("elision-next-syllable", queryStageContext 1 Stage.script queryElisionNextSyllable)
  , ("de-next", queryStageContext 1 Stage.script queryDeNext)
  , ("final-consonant-no-elision", queryStage Stage.script queryFinalConsonantNoElision)
  , ("word-basic-accent", queryStage Stage.script queryWordBasicAccent)
  , ("word-extra-accent", queryStage Stage.script queryWordExtraAccent)
  , ("word-accent-position", queryStage Stage.script queryWordAccentPosition)
  , ("word-force-acute", queryStage Stage.script queryWordForceAcute)
  , ("word-accent-with-position", queryStage Stage.script queryWordAccentWithPosition)
  , ("word-initial-aspiration", queryStage Stage.script queryWordInitialAspiration)
  , ("word-diaeresis-convention", queryStage Stage.script queryWordDiaeresisConvention)
  ]
