# demo.sh - while, for and if in the logOS shell
echo x > /flag
while rm /flag
do
  echo the loop body runs
done
for f in hello.txt rc
do
  echo --- /etc/$f
  cat /etc/$f
done
if cat /etc/passwd > /out
then
  echo found /etc/passwd
else
  echo no /etc/passwd
fi
rm /out
