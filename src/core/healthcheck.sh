#!/bin/sh

if pgrep -x ibmcloud > /dev/null; then
  exit 0
else
  exit 1
fi