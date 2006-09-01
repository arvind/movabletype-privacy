#!/usr/bin/perl -w

use strict;
BEGIN { unshift @INC, ($0 =~ m!(.*[/\\])! ? ( $1 . './lib', $1 . '../../lib', $1 . '../../extlib' ) : ( './lib', '../../lib', '../../extlib')) };
use MT::Bootstrap App => 'Privacy::CMS';
