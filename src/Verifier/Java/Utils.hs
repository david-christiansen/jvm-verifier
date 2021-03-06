{- |
Module           : $Header$
Description      : Utility functions for execution of JVM Symbolic programs
License          : BSD3
Stability        : provisional
Point-of-contact : acfoltzer
-}

{-# LANGUAGE ViewPatterns #-}
module Verifier.Java.Utils
  ( banners
  , dbugM
  , dbugV
  , headf
  , safeHead
  , splitN
  , boolSeqToValue
  , boolSeqToHex
  , hexToBoolSeq
  , hexToByteSeq
  , hexToNumSeq
  , hexToIntSeq
  )
where

import Data.Bits
import Data.Char
import Data.Int
import Data.List (foldl')

import Data.Maybe          (listToMaybe)
import Control.Monad.Trans

headf :: [a] -> (a -> a) -> [a]
headf [] _     = error "headf: empty list"
headf (x:xs) f = f x : xs

dbugM :: MonadIO m => String -> m ()
dbugM = liftIO . putStrLn

dbugV :: (MonadIO m, Show a) => String -> a -> m ()
dbugV desc v = dbugM $ desc ++ ": " ++ show v

banners :: MonadIO m => String -> m ()
banners msg = do
  dbugM $ replicate 80 '-'
  dbugM msg
  dbugM $ replicate 80 '-'

safeHead :: [a] -> Maybe a
safeHead = listToMaybe

boolSeqToValue :: (Bits a, Num a) => [Bool] -> a
boolSeqToValue bs = foldl' (.|.) 0  $ zipWith (\b i -> if b then bit i else 0) bs [0..]

splitN :: Int -> [a] -> [[a]]
splitN _ [] = []
splitN n l = h : splitN n r
  where (h,r) = splitAt n l

boolSeqToHex :: [Bool] -> String
boolSeqToHex bs = reverse (impl bs)
  where fn b i = if b then i else 0
        ch [x0, x1, x2, x3] = intToDigit (fn x3 8 + fn x2 4 + fn x1 2 + fn x0 1)
        ch _ = error "internal: 'char': unexpected input length"
        impl [] = []
        impl s = let (first',s1)  = splitAt 4 s
                     (second',s2) = splitAt 4 s1
                  in ch first' : ch second' : impl s2

hexToBoolSeq :: String -> [Bool]
hexToBoolSeq s =
  let ch c = map (testBit $ digitToInt c) [0..3]
      loop (x : y : rest) = ch x ++ ch y ++ loop rest
      loop [] = []
      loop _ = error "hexToBoolSeq: invalid string"
   in loop $ reverse s

hexToByteSeq :: String -> [Int32]
hexToByteSeq (x : y : r)
  = fromIntegral (16 * (digitToInt x) + (digitToInt y)) : hexToByteSeq r
hexToByteSeq [] = []
hexToByteSeq _ = error "internal: hexToByteSeq: invalid input string"

hexToNumSeq :: (Bits a, Num a) => Int -> String -> [a]
hexToNumSeq n = reverse . impl
  where impl xs | length xs >= n =
          foldr (+) 0 [ dToNum xi `shiftL` bi
                      | (xi, bi) <- xs `zip` reverse [4*i|i<-[0..n]]
                      ]
          : impl (drop n xs)
        impl [] = []
        impl _  = error "internal: hexToNumSeq invalid input string"
        dToNum  = fromIntegral . digitToInt
        
hexToIntSeq :: String -> [Int32]
hexToIntSeq = reverse . impl
  where impl (x0 : x1 : x2 : x3 : x4 : x5 : x6 : x7 : r)
         = fromIntegral (  (digitToInt x0) `shiftL` 28
                         + (digitToInt x1) `shiftL` 24
                         + (digitToInt x2) `shiftL` 20
                         + (digitToInt x3) `shiftL` 16
                         + (digitToInt x4) `shiftL` 12
                         + (digitToInt x5) `shiftL`  8
                         + (digitToInt x6) `shiftL`  4
                         + (digitToInt x7))
           : impl r
        impl [] = []
        impl _ = error "internal: hexToIntSeq invalid input string"
