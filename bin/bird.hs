module Main where
import Directory
import System.Process
import System.Environment (getArgs)
import List

main = do
  args <- getArgs
  runArg args

runArg arguments =
  case arguments of
    ["help"] -> printHelp
    ["--help"] -> printHelp
    ["nest"] -> do
      appModuleNamePath <- getCurrentDirectory
      appModuleName <- return $ head . reverse $ split '/' appModuleNamePath
      partialRouteFile <- readFile $ appModuleName ++ ".bird.hs"
      writeFile (appModuleName ++ ".hs") ((appModulePrelude appModuleName)++ "\n" ++ partialRouteFile ++ "\n" ++ appModuleEpilogue)
      system "ghc --make -O2 Main.hs"
      files <- getDirectoryContents appModuleNamePath
      system $ "rm *.o *.hi " ++ appModuleName ++ ".hs"
      renameFile "Main" appModuleName
      return ()
    ["fly"] -> do
      appModuleNamePath <- getCurrentDirectory
      appModuleName <- return $ head . reverse $ split '/' appModuleNamePath
      system $ "./" ++ appModuleName
      return ()
    ("hatch":appName:options) -> createBirdApp appName options
    (action:_) -> do
      putStrLn $ "Unrecognized action: " ++ (show action) ++ "\n"
      printHelp
    [] -> printHelp

printHelp = do
  putStrLn $ "Usage: bird action [options]\n\n" ++
             "  Actions:\n" ++
             "    hatch -> create a new Bird app, takes the name as an argument, for example `bird hatch StarWars`\n" ++
             "    nest  -> compile your Bird app\n" ++
             "    fly   -> expose your Bird app to the world (on port 3000)\n"

appModulePrelude appModuleName =
  "--This file is generated by bird. It will be overwritten the next time you run 'bird nest'. Edit at your own peril.\n" ++
  "module " ++ appModuleName ++ " where\n" ++
  "import Bird\n\n"

appModuleEpilogue =
  "get _ = status 404\n" ++
  "post _ = status 404\n" ++
  "put _ = status 404\n" ++
  "delete _ = status 404\n"


createBirdApp a options = do
  createDirectory a
  writeFile (a ++ "/" ++ a ++ ".bird.hs") (routeFile a)
  let mainFileName = a ++ "/" ++ "Main.hs"
  case options of 
    [] -> writeFile mainFileName (mainFileHack a)
    ["--wai"] -> writeFile mainFileName (mainFileWai a)
  putStrLn $ "A fresh Bird app has been created in " ++ a ++ "."

routeFile a = "get [] = body \"Hello, Bird!\""

mainFileHack a =
  "import Hack\n" ++
  "import qualified Hack as Hack\n" ++
  "import Hack.Handler.Happstack\n" ++
  "import Bird\n" ++
  "import qualified Bird as Bird\n" ++
  "import Bird.Translator.Hack\n" ++
  "import qualified Control.Monad.State as S\n" ++
  "import qualified Control.Monad.Reader as R\n" ++
  "import " ++ a ++ "\n" ++ "\n" ++

  "app :: Application\n" ++
  "app = \\e -> route e\n" ++ "\n" ++

  "route :: Env -> IO Response\n" ++
  "route e = response\n" ++
  "  where \n" ++
  "    req = toBirdRequest e\n" ++
  "    response = do \n" ++
  "      reply <- runBirdResponder req matchRequest\n" ++
  "      return $ fromBirdReply reply\n\n" ++

  "matchRequest r = \n" ++
  "  case verb r of \n" ++
  "    Bird.GET -> get $ path r\n" ++
  "    Bird.POST -> post $ path r\n" ++
  "    Bird.PUT -> put $ path r\n" ++
  "    Bird.DELETE -> delete $ path r\n\n" ++

  "main = run app\n"

mainFileWai a = 
  "{-# LANGUAGE OverloadedStrings #-}\n" ++
  "import Network.Wai\n" ++
  "import Network.Wai.Enumerator (fromLBS)\n" ++
  "import Network.Wai.Handler.SimpleServer (run)\n" ++
  "import Bird\n" ++
  "import qualified Bird as Bird\n" ++
  "import Bird.Translator.Wai\n" ++
  "import qualified Control.Monad.State as S\n" ++
  "import qualified Control.Monad.Reader as R\n" ++
  "import " ++ a ++ "\n" ++ "\n" ++


  "app :: Application\n" ++
  "app = \\e -> route e\n\n" ++

  "route :: Wai.Request -> IO Response\n" ++
  "route e = response\n" ++
  "  where \n" ++
  "    req = toBirdRequest e\n" ++
  "    response = do \n" ++
  "      reply <- runBirdResponder req matchRequest\n" ++
  "      return $ fromBirdReply reply\n\n" ++

  "matchRequest r = \n" ++
  "  case verb r of \n" ++
  "    Bird.GET -> get $ path r\n" ++
  "    Bird.POST -> post $ path r\n" ++
  "    Bird.PUT -> put $ path r\n" ++
  "    Bird.DELETE -> delete $ path r\n\n" ++

  "main :: IO ()\n" ++
  "main = do\n" ++
  "    putStrLn $ \"http://localhost:8080/\"\n" ++
  "    run 8080 app\n\n" ++




split :: Char -> String -> [String]
split d s
  | findSep == [] = []
  | otherwise     = t : split d s''
    where
      (t, s'') = break (== d) findSep
      findSep = dropWhile (== d) s
