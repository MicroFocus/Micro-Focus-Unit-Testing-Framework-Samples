#!/bin/sh
TARGET=native
SRC_NOEXT="BBANK30P BBANK70P"
MFUPP_DIR="-C p(mfupp) CONFIRM VERBOSE CICS(IGNORE) MOCK(CICS) p(cp) endp endp"
MF_RM="rm -f"
NAME=bankdemo

. ./bld_is_enterprise.sh
if [ "x$_DFHEIBLK_FILE" = "x" ]
then
	echo Sorry demo $NAME is not supported for use with this product
	exit 1
fi


rm -f ./*.int ./*.so ./*.mfupp.txt ./*.lst
COBCPY=$(pwd)/tests:$(pwd)/cpylib:.:$COBCPY
export COBCPY

# ensure we can find the .csv files
MFU_DS=$(pwd)/tests:
export MFU_DS

# make it pretty, if we can
MFU_ARG=
if [ "x$TERM" = "xxterm-256color" ]
then
	cobmfurun | grep diagnostics-color >/dev/null
	test $? -eq 0  && MFU_ARG=-diagnostics-color:ansi
fi

bld_native() {
	set -x
	for i in $SRC_NOEXT
	do
		echo Compiling : $i.cbl
		cob -via "$MFUPP_DIR" $i.cbl 
		# cob64 -via -C "P(mfupp) CONFIRM VERBOSE CICS(IGNORE) MOCK(CICS) EXEC-REPORT-FILE P(cp) ENDP" $i.cbl 

	done
	cob -zg -e "" -o tests.so ./*.int

	cobmfurun -verbose $MFU_ARG $REPORT_ARGS -outdir:results tests.so

	$MF_RM ./TEST*xml
	$MF_RM  ./*.int ./*.so ./*.mfupp-et ./*.o ./*.idy
}


bld_jvm() {
	rm -rf jbin
	mkdir -p jbin	
	
	for i in tests/*.cbl
	do
		if [ -f $i ]
		then
			echo Compiling : $i
			cob -vj -C nolitlink -C iloutput\"jbin\" -C ilnamespace\"com.rocketsoftware.test\" "$MFUPP_DIR" $i
		fi
	done

	for i in $SRC_NOEXT
	do
		echo Compiling : $i.cbl
		if [ -f $i.dir ]
		then
			cob -vj -C 'use"'$i.dir'"' -C iloutput\"jbin\" -C ilnamespace\"com.rocketsoftware.test\" "$MFUPP_DIR" $i.cbl
		else
			cob -vj -C iloutput\"jbin\" -C ilnamespace\"com.rocketsoftware.test\" "$MFUPP_DIR" $i.cbl
		fi
	done

	jar cvf examples.jar -C jbin .
	mfjarprogmap -jar examples.jar
	cobmfurunj $MFU_ARG $REPORT_ARGS -outdir:results examples.jar
	$MF_RM $i.o $i.int $i.idy $i.so examples.jar
}

bld_net8() {
	cd dn8
	dotnet build /t:rebuild "/p:MFUnitRunnerCommandGenerateArguments=$REPORT_ARGS" /t:run
	dotnet build /t:clean
	cd ..
	mkdir -p results
	cp dn8/bin/*/net8.0/TEST*.xml results/
	cp dn8/bin/*/net8.0/*-report.txt results/
}

for i in $*
do
	case .$i in
		.native) TARGET=native ;;
		.jvm) TARGET=jvm ;;
		.net8) TARGET=net8 ;;
		.norm) MF_RM="echo norm set: leaving files: " ;;
		*) echo $0: Invalid argument $i
		   exit 1 
		   ;;
	esac
done
JUNIT_PACKAGE=com.rocketsoftware.sample.$TARGET
REPORT_NAME=${NAME}_${TARGET}-report.txt
REPORT_ARGS="-report:junit -junit-packname:$JUNIT_PACKAGE. -report:printfile -reportfile:$REPORT_NAME"

echo TARGET is $TARGET

bld_$TARGET
