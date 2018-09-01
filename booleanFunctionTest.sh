readonly TRUE="TRUE" # can be any unique string
readonly FALSE="FALSE" # can be any unique string

isTrue(){
    [[ "$1" == "$TRUE" ]]
}
isNotTrue(){
    if isTrue "$1"
    then
        return 1
    else
        return 0
    fi
}

# to check boolean functions, assert the following:

if isTrue "$TRUE"; then echo "OK"; else echo "not OK"; fi
if isTrue "$FALSE"; then echo "not OK"; else echo "OK"; fi
if isTrue "another string"; then echo "not OK"; else echo "OK"; fi

if isNotTrue "$TRUE"; then echo "not OK"; else echo "OK"; fi
if isNotTrue "$FALSE"; then echo "OK"; else echo "not OK"; fi
if isNotTrue "another string"; then echo "OK"; else echo "not OK"; fi
if isTrue "$TRUE" && isNotTrue "$FALSE"; then echo "OK"; else echo "not OK"; fi

if isTrue "$TRUE" && isNotTrue "$FALSE"; then echo "OK"; else echo "not OK"; fi
if isTrue "$TRUE" && isNotTrue "$TRUE"; then echo "not OK"; else echo "OK"; fi
if isTrue "$FALSE" && isNotTrue "$FALSE"; then echo "not OK"; else echo "OK"; fi
if isTrue "$FALSE" && isNotTrue "$TRUE"; then echo "not OK"; else echo "OK"; fi
if isTrue "$TRUE" || isNotTrue "$FALSE"; then echo "OK"; else echo "not OK"; fi
if isTrue "$TRUE" || isNotTrue "$TRUE"; then echo "OK"; else echo "not OK"; fi
if isTrue "$FALSE" || isNotTrue "$FALSE"; then echo "OK"; else echo "not OK"; fi
if isTrue "$FALSE" || isNotTrue "$TRUE"; then echo "not OK"; else echo "OK"; fi
