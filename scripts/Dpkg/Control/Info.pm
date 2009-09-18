# Copyright © 2007 Raphaël Hertzog <hertzog@debian.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package Dpkg::Control::Info;

use strict;
use warnings;

use Dpkg::Control;
use Dpkg::ErrorHandling;
use Dpkg::Gettext;

=head1 NAME

Dpkg::Control::Info - parse files like debian/control

=head1 DESCRIPTION

It provides an object to access data of files that follow the same
syntax than debian/control.

=head1 FUNCTIONS

=over 4

=item $c = Dpkg::Control::Info->new($file)

Create a new Dpkg::Control::Info object for $file. If $file is omitted, it parses
debian/control. If file is "-", it parses the standard input.

=cut

sub new {
    my ($this, $arg) = @_;
    my $class = ref($this) || $this;
    my $self = {
	'source' => undef,
	'packages' => [],
    };
    bless $self, $class;
    if ($arg) {
        if ($arg eq "-") {
            $self->parse_fh(\*STDIN, _g("standard input"));
        } else {
            $self->parse($arg);
        }
    } else {
	$self->parse("debian/control");
    }
    return $self;
}

=item $c->reset()

Resets what got read.

=cut

sub reset {
    my $self = shift;
    $self->{source} = undef;
    $self->{packages} = [];
}

=item $c->parse($file)

Parse the content of $file. Exits in case of errors.

=cut

sub parse {
    my ($self, $file) = @_;
    open(CDATA, "<", $file) || syserr(_g("cannot read %s"), $file);
    $self->parse_fh(\*CDATA, $file);
    close(CDATA);
}

=item $c->parse_fh($fh, $description)

Parse a control file from the given filehandle. Exits in case of errors.
$description is used to describe the filehandle, ideally it's a filename
or a description of where the data comes from. It's used in error
messages.

=cut

sub parse_fh {
    my ($self, $fh, $desc) = @_;
    $self->reset();
    my $cdata = parsecdata($fh, $desc);
    return if not defined $cdata;
    $self->{source} = $cdata;
    unless (exists $cdata->{Source}) {
	syntaxerr($desc, _g("first block lacks a source field"));
    }
    while (1) {
	$cdata = parsecdata($fh, $desc);
	last if not defined $cdata;
	push @{$self->{packages}}, $cdata;
	unless (exists $cdata->{Package}) {
	    syntaxerr($desc, _g("block lacks a package field"));
	}
    }
}

=item $c->get_source()

Returns a reference to a hash containing the fields concerning the
source package. The hash is tied to Dpkg::Fields::Object.

=cut

sub get_source {
    my $self = shift;
    return $self->{source};
}

=item $c->get_pkg_by_idx($idx)

Returns a reference to a hash containing the fields concerning the binary
package numbered $idx (starting at 1). The hash is tied to
Dpkg::Fields::Object.

=cut

sub get_pkg_by_idx {
    my ($self, $idx) = @_;
    return $self->{packages}[--$idx];
}

=item $c->get_pkg_by_name($name)

Returns a reference to a hash containing the fields concerning the binary
package named $name. The hash is tied to Dpkg::Fields::Object.

=cut

sub get_pkg_by_name {
    my ($self, $name) = @_;
    foreach my $pkg (@{$self->{packages}}) {
	return $pkg if ($pkg->{Package} eq $name);
    }
    return undef;
}


=item $c->get_packages()

Returns a list containing the hashes for all binary packages.

=cut

sub get_packages {
    my $self = shift;
    return @{$self->{packages}};
}

=item $c->dump($filehandle)

Dump the content into a filehandle.

=cut

sub dump {
    my ($self, $fh) = @_;
    tied(%{$self->{source}})->dump($fh);
    foreach my $pkg (@{$self->{packages}}) {
	print $fh "\n";
	tied(%{$pkg})->dump($fh);
    }
}

=back

=head1 AUTHOR

Raphael Hertzog <hertzog@debian.org>.

=cut

1;