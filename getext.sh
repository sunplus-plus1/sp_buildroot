SP_IMB_ROOT=`basename $1 | tr "." " "`
SP_IMB_EXT=

for i in $SP_IMB_ROOT
do
  SP_IMB_EXT=$i
done

echo $SP_IMB_EXT