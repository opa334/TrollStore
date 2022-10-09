{ LDID_OUTPUT="$( { ldid; } 2>&1 1>&3 3>&- )"; } 3>&1;
echo "aaa: $LDID_OUTPUT"