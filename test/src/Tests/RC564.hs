{- |
Module           : $Header$
Description      :
Stability        : provisional
Point-of-contact : jstanley
-}

{-# LANGUAGE CPP #-}

module Tests.RC564 (rc564Tests) where

import Control.Applicative
import Control.Monad
import qualified Data.Vector as V
import System.Process
import Test.QuickCheck
import Test.QuickCheck.Monadic

import JavaParser
import Simulation hiding (run)
import Tests.Common
import Utils

import Verinf.Symbolic

rc564Tests :: [(Args, Property)]
rc564Tests =
  [ -- dag-based eval only for RC564 on two random 128b inputs
    ( stdArgs{ maxSuccess = 10 }
    , label "RC5-64 random keys/messages" $ monadicIO $
        -- run $ putStrLn "Running RC5-64 test..."
        forAllM (bytes 16) $ \key ->
          forAllM (bytes 16) $ \inp -> do
            evalDagRC564 key inp
    )
  ]

_ignore_nouse :: a
_ignore_nouse = undefined main

main :: IO ()
main = runTests rc564Tests

--------------------------------------------------------------------------------
-- RC-564

getGoldenRC564 :: String -> String -> IO String
getGoldenRC564 key inp =
  readProcess "java"
              [ "-classpath"
#ifdef mingw32_HOST_OS
              , "user/bcprov-jdk16-145.jar;jdk1.6/classes.jar;test/src/support"
#else
              , "user/bcprov-jdk16-145.jar:jdk1.6/classes.jar:test/src/support"
#endif
              , "TestRC564"
              , key
              , inp
              ]
              ""

-- TODO: add evalAigRC564 etc.
evalDagRC564 :: String -> String -> PropertyM IO ()
evalDagRC564 key input = do
  cb     <- commonCB
  oc <- run mkOpCache
  golden <- run $ getGoldenRC564 key input
--   run $ putStrLn $ "Key    : " ++ key
--   run $ putStrLn $ "Input  : " ++ input
--   run $ putStrLn $ "Golden : " ++ golden
  rslt <- run $ withSymbolicMonadState oc $ \sms -> do
    let sbe = symbolicBackend sms 
    keyVars <- replicateM 16 $ freshByte sbe
    inpVars <- replicateM 16 $ freshByte sbe
    outVars <- runDefSimulator sbe cb $ runRC564 keyVars inpVars
    let inpValues = V.map constInt
                  $ V.fromList
                  $ hexToByteSeq key ++ hexToByteSeq input
    evalFn <- concreteEvalFn inpValues
    byteSeqToHex <$> mapM evalFn outVars
  assert $ rslt == golden
--   run $ putStrLn $ "Result : " ++ rslt

_makeAigerRC564 :: String -> IO ()
_makeAigerRC564 filepath = do
  cb <- commonLoadCB
  oc <- mkOpCache
  putStrLn "Simulating RC564"
  withSymbolicMonadState oc $ \sms -> do
    let sbe = symbolicBackend sms
    let be = smsBitEngine sms
    keyVars <- replicateM 16 $ freshByte sbe
    inpVars <- replicateM 16 $ freshByte sbe
    outValues <- runDefSimulator sbe cb $ runRC564 keyVars inpVars
    putStrLn "Creating RC564 aiger..."
    outLits <- mapM (getVarLit sbe) outValues
    putStrLn $ "Writing RC564 aiger to '" ++ filepath ++ "'"
    writeAiger be filepath $ concat (map (take 8 . toLsbf_lit) outLits)

runRC564 :: AigOps sym =>
            [MonadTerm sym] -> [MonadTerm sym] -> Simulator sym [MonadTerm sym]
runRC564 keyVars inpVars = do
  let byteArrayType = ArrayType ByteType
  keyArray <- newIntArray byteArrayType keyVars
  inpArray <- newIntArray byteArrayType inpVars
  l16 <- withSBE $ \sbe -> termInt sbe 16
  outArray <- newMultiArray byteArrayType [l16]
  [(pd,Terminated)] <- runStaticMethod "TestRC564"
                                       "rc564_encrypt"
                                       "([B[B[B)V"
                                       [ RValue keyArray
                                       , RValue inpArray
                                       , RValue outArray
                                       ]
  getIntArray pd outArray
