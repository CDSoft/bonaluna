(cd ..; make bl) || return
cp ../bl /tmp/bl
upx --best /tmp/bl
../bl glue.lua read:/tmp/bl lua:hello.lua lua:exit.lua write:hello read:hello
chmod +x hello
hello a b c
