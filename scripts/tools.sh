#!/bin/bash

alias hidpi='bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"'

cheat() {
  curl -s cheat.sh/"$@"
}