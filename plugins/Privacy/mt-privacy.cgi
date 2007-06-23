#!/usr/bin/perl -w
# Privacy - A plugin for Movable Type.
# Copyright (c) 2005-2007, Arvind Satyanarayan.

use strict;
BEGIN { unshift @INC, ($0 =~ m!(.*[/\\])! ? ( $1 . './lib', $1 . '../../lib', $1 . '../../extlib' ) : ( './lib', '../../lib', '../../extlib')) };
use MT::Bootstrap App => 'Privacy::App::Authenticate';
