#!/usr/bin/bash

# Crude CRUD user interface to Postgresql data base
#
# Copyright 2015, Berend M. Tober
#

me=$(basename $0)

function syntax {
  echo "SYNTAX: $me [-e] host database username"
  echo "CTRL-D to exit"
  echo 
  echo "Option"
  echo "  -e  Execute query. The default is to only print generated query commands to stdout."
  echo
}
  
if [ $# -lt 3 ]
then
  syntax
  exit
fi

while [ "$#" -gt 0 ]
do
  case $1 in
    -\?|-h)
      shift
      syntax
      exit
      ;;
    -e)
      queryexecute=1
      shift;;
    -*)
      echo "invalid option '${1}'"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

dbhost="$1"
dbdata="$2"
dbuser="$3"

function dbselect {
  # Construct a SQL select statement
  local fieldlist=$(psql -h "$dbhost" -AtU "$dbuser" "$dbdata" <<< "\d $table" | awk -F"|" '{printf("%s, ",$1)}')
  fieldlist=${fieldlist%", "}
  query='select '"$fieldlist"' from '"$table"';'
}

function dbinsert {
  # Construct a SQL insert statement
  local fieldlist=""
  local valuelist=""

  for f in $(psql -h "$dbhost" -AtU "$dbuser" "$dbdata" <<< "\d $table" | awk -F"|" '{printf("%s\n",$1)}' )
  do
    read -p "$f=" v
    if [ ! -z "${v}" ]
    then
      fieldlist="${fieldlist}${f}, "
      valuelist="${valuelist}${v}, "
    fi
  done

  fieldlist=${fieldlist%", "}
  valuelist=${valuelist%", "}

  if [ -z "${fieldlist}" -a -z "${valuelist}" ]
  then
    query="insert into $table default values;"
  else
    query="insert into $table (${fieldlist}) values (${valuelist});"
  fi
}

function dbupdate {
  # Construct a SQL update statement
  local fieldlist=""
  local setlist=""
  local whereclause=""

  fieldlist=$(psql -h "$dbhost" -AtU "$dbuser" "$dbdata" <<< "\d $table" | awk -F"|" '{printf("%s ",$1)}')
  for f in ${fieldlist}
  do
    read -p "set $f=" v
    if [ ! -z "${v}" ]
    then
      setlist="${setlist}${f}=${v}, "
    fi
  done

  setlist=${setlist%", "}

  for f in ${fieldlist}
  do
    read -p "where $f=" v
    if [ ! -z "${v}" ]
    then
      whereclause="${whereclause}${f}=${v} and "
    fi
  done

  whereclause=${whereclause%" and "}
  [ ! -z "$whereclause" ] && whereclause="where $whereclause"
  query="update table $table set $setlist $whereclause;"
}

function dbdelete {
  # Construct a SQL delete statement
  local whereclause=""

  for f in $(psql -h "$dbhost" -AtU "$dbuser" "$dbdata" <<< "\d $table" | awk -F"|" '{printf("%s ",$1)}')
  do
    read -p "where $f=" v
    if [ ! -z "${v}" ]
    then
      whereclause="${whereclause}${f}=${v} and "
    fi
  done

  whereclause=${whereclause%" and "}
  [ ! -z "$whereclause" ] && whereclause="where $whereclause"
  query="delete from $table $whereclause;"
}

function crudmenu {
  # CRUD menu for selected table
  psql -h "$dbhost" -U "$dbuser" "$dbdata" <<< "\d $table" >&2
  options=("C - Add data" "R - List data" "U - Modify data" "D - Delete")
  select opt in "${options[@]}"
  do
    case ${opt:0:1} in 
      "C")
        dbinsert
        ;;
      "R")
        dbselect
        ;;
      "U")
        dbupdate
        ;;
      "D")
        dbdelete
        ;;
    esac
    echo "$query" 
    [ ${queryexecute-0} -eq 1 ] && psql -h "$dbhost" -U "$dbuser" "$dbdata" <<< "$query" 
  done
}

function tablemenu {
  # Menu listing tables visible to user
  tables=$(psql -h "$dbhost" -AtU "$dbuser" "$dbdata" <<< "\d" | awk -F"|" '{printf("%s ", $2)}')

  unset table
  select table in ${tables}
  do
    if [ -z "${table}" ]
    then
      echo "Exiting"
      exit
    else  
      crudmenu
    fi
  done

}  

tablemenu

