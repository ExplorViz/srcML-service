#!/usr/bin/python

import os
import sys

machines = [
      "suse132build"
    , "suse132test"
    , "suse132build64"
    , "suse132test64"
    , "ubuntu14build"
    , "ubuntu14test"
    , "ubuntu14build64"
    , "ubuntu14test64"
    , "ubuntu16build64"
    , "mint17build"
    , "mint17test"
    , "mint171build"
    , "mint171test"
    , "mint17build64"
    , "mint17test64"
    , "mint171build64"
    , "mint171test64"
]

options = []

argv = sys.argv[:]

background = ""

for arg in sys.argv[1:] :

    if arg.lower().find("--bg") == 0 :
        background = "true"
        argv.remove(arg)

    elif arg.find("--") == 0 :
        options.append(str(arg.lstrip("-")).lower())
        argv.remove(arg)
    else :
        break;

matches = machines[:]

for option in options :

    for machine in machines :

        if machine not in matches :
            continue

        if option[0] == '~' :           
            if machine.lower().find(option[1:]) != -1 :
                matches.remove(machine)
        else :
            if machine.lower().find(option) == -1 :
                matches.remove(machine)

args = "'"

for arg in argv[1:] :

    args += " " + arg
args += "'"

if args == "''" :
    args = ""

if background == "" :
    for match in matches :

        command = "ssh root@" + match + " " + args
        print command

        os.system(command)
else :
    list = "'"
    for match in matches :
        
        list += match + "\\n"
    list += "'"

    command = "gecho -e " + list + " | gxargs -I% -t ssh root@" + "'%' " + args 
    print command

    os.system(command)
