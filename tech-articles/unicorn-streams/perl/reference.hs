{--
  File to test assumptions about lazyness.
--}
module Main where

dropAt :: Int -> [Int] -> [Int]
dropAt n ls = take n ls ++ drop (n+1) ls

-- Slow fib function
fib :: Int -> Int
fib n 
  | n < 2     = n
  | otherwise = fib (n-1) + fib (n-2)

-- Applies a slow function over a list in order to test how
-- long the application continues.
slowList :: [Int] -> [Int]
slowList = map (\_ -> fib 30)


-- Should eval only the first 3 elems
dropAtTest1 = take 3 . dropAt 7 . slowList $ [1..10]
