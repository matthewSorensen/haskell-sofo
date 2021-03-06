import Control.Applicative

newtype MiniParser a = MiniParser {
  unMP :: String -> Maybe (String, a)
  }

instance Functor MiniParser where
  fmap f p = let up = unMP p
                 g s = h <$> up s
                 h (s, a) = (s, f a)
             in MiniParser g

instance Applicative MiniParser where
  pure a = MiniParser $ \s -> Just (s, a)
  pf <*> pa = let upf = unMP pf
                  upa = unMP pa
                  g s = h <$> upf s
                  h (s, f) = i f <$> upa s
                  i f (s, a) = (s, f a)
              in MiniParser $ join . g
    where join (Just (Just a)) = Just a
          join _ = Nothing

instance Alternative MiniParser where
  empty = MiniParser $ const Nothing
  pa <|> pb = let upa = unMP pa
                  upb = unMP pb
                  g s = maybe (upb s) Just (upa s)
              in MiniParser g

sequenceA :: Applicative f => [f a] -> f [a]
sequenceA fs = foldr (\x ys -> (:) <$> x <*> ys) (pure []) fs

runParser :: MiniParser a -> String -> Maybe a
runParser p s = snd <$> (unMP p s)

runParserComplete :: MiniParser a -> String -> Maybe a
runParserComplete p s = f $ unMP p s
  where f (Just ("", a)) = Just a
        f _ = Nothing

charP :: Char -> MiniParser Char
charP c = MiniParser f
  where f "" = Nothing
        f (x:xs)
          | x == c = Just (xs, c)
          | otherwise = Nothing

wordP :: String -> MiniParser String
wordP = sequenceA . map charP

-- SAMPLE USAGE

data AB = A | B deriving (Show)

-- | Parser for the string "a", when successful will return the value A
aP :: MiniParser AB
aP = const A <$> charP 'a'

-- | Parser for the string "b", when successful will return the value A
bP :: MiniParser AB
bP = const B <$> charP 'b'

-- | Parser for the string "ab", when successful will return the value (A, B)
abP :: MiniParser (AB, AB)
abP = (,) <$> aP <*> bP

-- | Parser for the string "a" or the string "b"
aOrBP :: MiniParser AB
aOrBP = aP <|> bP

-- | Parser for strings that consist of only 'a's
manyAP :: MiniParser [AB]
manyAP = many aP

-- | Parser for strings that consist of only 'a's and 'b's
manyAOrBP :: MiniParser [AB]
manyAOrBP = many (aP <|> bP)

-- | Parser for strings that consist of some number of 'a's, then some number of 'b's
someAsomeBP :: MiniParser [AB]
someAsomeBP = (++) <$> many aP <*> many bP

-- | Parser for strings that consist of some number n 'a's, then exactly n 'b's,
-- which returns n. Demonstration of parsing a non-regular LL(1) context-free
-- grammar!
nAsNBsP :: MiniParser Int
nAsNBsP = aSomethingB <|> middle
  where aSomethingB = (+ 1) <$> (aP *> nAsNBsP <* bP)
        middle = pure 0

abbaP :: MiniParser [AB]
abbaP = const [A, B, B, A] <$> wordP "abba"
