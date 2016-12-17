#!/usr/bin/env bash

# vim: set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab:

# Rebuilds both KERNEL and WORLD on a FreeBSD system to
# follow the FreeBSD STABLE release branch.

# This script attempts to automate the task of rebuilding an entire system
# stack of a FreeBSD machine (src / ports, respectively). It obtains a fresh
# clone of both /usr/src and /usr/ports via svn (Subversion), then rebuilds
# world and the kernel using a copy of the GENERIC kernel configuration file
# using the upper-cased version of the hostname of the machine. It will also
# guide the user through those tasks, so minimizes the effects of human error.

##############################################################################
### Copyright (c) <2016> Armin <a@m2m.pm>, released under the terms of the ###
### MIT BSD like license                                                   ###
##############################################################################

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Define kernel configuration file name / architecture / release version
kernconf="$(a="$(hostname)"; b="$(echo "${a%%.*}" | tr '[:lower:]' '[:upper:]')"; echo "$b")"
echo "Using kernel configuration (KERNCONF): $kernconf"

arch="amd64"
release="11"

# define /usr/src / /usr/ports SVN repository URLs
svn_src_url="https://svn0.us-west.freebsd.org/base/stable/${release}"
svn_ports_url="https://svn0.us-west.freebsd.org/base/stable/${release}"

bailout () {
  echo -n "${0}: Error: "
  echo "$@"
  exit 1
}

# include hidden files in globs (for /usr/src / /usr/ports checks)
shopt -s nullglob dotglob

# TODO: get rid of that copy/paste code block mess below, dude
if [ -e /usr/src ]; then
  files=(/usr/src/*)
  if [[ ! "${#files[@]}" -gt 0 ]]; then
    # Edge-case: /usr/src does exist, but is empty
    echo "=== /usr/src exists, but is empty."
    echo "=== Obtaining /usr/src via SVN ..."
    sleep 1
    mv /usr/src /usr/src.rebuild.pre
    cd /usr
    svn co "$svn_src_url" /usr/src
  else
    if [[ ! /usr/src/.svn ]]; then
      echo "=== /usr/src exists but wasn't obtained via SVN."
      echo "=== Obtaining fresh copy of /usr/src via SVN ..."
      sleep 1
      mv /usr/src /usr/src.rebuild.pre
      svn co "$svn_src_url" /usr/src
    else
      # /usr/src exists and is non-empty, so it's safe to call svn up
      echo "=== Updating /usr/src via SVN ..."
      sleep 1
      cd /usr/src
      svn up
      cd -
    fi
  fi
else
  cd /usr
  echo "=== Obtaining fresh clone of /usr/src via SVN ..."
  sleep 1
  svn co "$svn_src_url" /usr/src
fi

if [ -e /usr/ports ]; then
  files=(/usr/ports/*)
  if [[ ! "${#files[@]}" -gt 0 ]]; then
    # Edge-case: /usr/ports does exist, but is empty
    echo "=== /usr/ports exists, but is empty."
    echo "=== Obtaining /usr/ports via SVN ..."
    sleep 1
    mv /usr/ports /usr/ports.rebuild.pre
    cd /usr
    svn co "$svn_ports_url" /usr/ports
  else
    if [[ ! /usr/ports/.svn ]]; then
      echo "=== /usr/ports exists but wasn't obtained via SVN."
      echo "=== Obtaining fresh copy of /usr/ports via SVN ..."
      sleep 1
      mv /usr/ports /usr/ports.rebuild.pre
      svn co "$svn_ports_url" /usr/ports
    else
      # /usr/ports exists and is non-empty, so it's safe to call svn up
      echo "=== Updating /usr/ports via SVN ..."
      sleep 1
      cd /usr/ports
      svn up
      cd -
    fi
  fi
else
  cd /usr
  echo "=== Obtaining fresh clone of /usr/ports via SVN ..."
  sleep 1
  svn co "$svn_ports_url" /usr/ports
fi

if [ -e /usr/src/sys/amd64/conf/${kernconf} ]; then
  echo "=== Using existing kernel configuration file $kernconf"
else
  echo "=== Generating new kernel configuration file $kernconf (based on GENERIC)..."
  cat /usr/src/sys/amd64/conf/GENERIC | sed "s/GENERIC/${kernconf}/g" > /usr/src/sys/amd64/conf/${kernconf}
fi

cd /usr/src

echo ">>> Building WORLD..."
make buildworld -j4

echo ">>> Building KERNEL (${kernconf})..."
make buildkernel KERNCONF=${kernconf}

echo ">>> Installing KERNEL (${kernconf})..."
make installkernel KERNCONF=${kernconf}

echo
echo ">>> [installkernel] completed."
echo
echo "=== It's time to reboot and run \"make installworld\" now. ==="
echo
echo "NOTE: You'll have to reboot after installing the new world distribution:"
echo
echo "[reboot]"
echo "# cd /usr/src"
echo "# make installworld KERNCONF=BASE"
echo "[reboot]"
echo "# echo 'hooray'"
echo ""

exit 0


