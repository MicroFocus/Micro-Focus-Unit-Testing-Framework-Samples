@echo off
setlocal enableextensions 
setlocal enabledelayedexpansion

call bld_is_enterprise.bat
if .%_SQLCA_FILE% == . (
  SET "CDIR=%~dp0"
  SET "CDIR=!CDIR:~0,-1!"
  FOR %%i IN ("!CDIR!") DO SET "PARENTFOLDERNAME=%%~nxi"
  echo Sorry demo !PARENTFOLDERNAME! is not supported for use with this product
  goto theend
)

set TARGET=native
set NAME=cics_updcustid

:top_args
if .%1 == . goto args_end
if /I .%1 == .jvm (
  set TARGET=jvm
  goto arg_okay
  )

if /I .%1 == .net6 (
  set TARGET=net6
  goto arg_okay
  )

echo Invalid argument %1 
goto theend

:arg_okay
shift
goto top_args
:args_end

set JUNIT_PACKAGE=com.rocketsoftware.sample.%TARGET%
set REPORT_NAME=%NAME%_%TARGET%-report.txt
set "REPORT_ARGS=-report:junit -junit-packname:%JUNIT_PACKAGE% -report:printfile -reportfile:%REPORT_NAME%"
echo TARGET is %TARGET%
echo REPORT_ARGS is %REPORT_ARGS%

set COBCPY=%CD%\cpylib;%CD%\tests;%COBCPY%;.
set "MFUPP_DIR=p(mfupp) CONFIRM VERBOSE CICS(IGNORE) MOCK(CICS) endp"

set MFU_DS=%CD%\tests
set MFU_DD_DIR=%CD%\tests

goto bld_%TARGET%

:check_native_extra
for /f "tokens=4-5 delims= " %%i in ('ver') do (
  if "%%j"=="" (set v=%%i) else (set v=%%j)
)
for /f "tokens=1-3 delims=.]" %%i in ("%v%") do (
  set OS_VER_MAJOR=%%i
  set OS_VER_MINOR=%%j
  set OS_BUILD_NUM=%%k
)
if %OS_VER_MAJOR% == 10 (
    set extra_arg=-dc:windows10 
)
if NOT .%WT_SESSION% == . (
    set extra_arg=-dc:ansi
)
goto theend

:check_jvm_extra
if NOT .%WT_SESSION% == . (
    set extra_arg=-dc:ansi
)
goto theend

:bld_native
call :check_native_extra
echo Compiling Sources:
for %%i in (*.cbl) do cobol %%i omf(obj) anim %MFUPP_DIR%;
dir/b *.obj >examples.lnk
cbllink -Dexamples.dll @examples.lnk
mfurun %REPORT_ARGS% -generate-mfu examples.dll
mfurun %extra_arg% -outdir:results -jit:nodebug -verbose examples.mfu
@del examples.mfu examples.dll *.obj *.idy examples.lnk examples.mfgcf
goto theend

:bld_jvm
call :check_jvm_extra
mkdir jbin >nul: 2>&1
for %%i in (*.cbl) do cobol %%i jvmgen(sub) anim  iloutput"jbin" ilnamespace"com.rocketsoftware.test" %MFUPP_DIR%;
jar cvf  examples.jar -C jbin .
call mfjarprogmap.bat -jar examples.jar
call mfurunj.bat %REPORT_ARGS% -generate-mfu examples.jar
call mfurunj.bat %extra_arg% -outdir:results -verbose examples.mfu

@del examples.mfu examples.jar *.obj *.idy examples.lnk examples.mfgcf
goto theend

:bld_net6
if not exist results md results
pushd dn6
dotnet build /t:clean
dotnet build "/p:MFUnitRunnerCommandGenerateArguments=%REPORT_ARGS%" /t:rebuild /t:run
copy bin\Debug\net6.0\*report.txt ..\results
copy bin\Debug\net6.0\TEST*xml ..\results
@REM dotnet build /t:clean
popd
goto theend
:theend

