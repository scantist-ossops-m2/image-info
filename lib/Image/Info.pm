
#############################################################################
#
# ATTENTION! This file is autogenerated from dev/Info.pm.tmpl - DO NOT EDIT!
#
#############################################################################

package Image::Info;

# Copyright 1999-2004, Gisle Aas.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl v5.8.8 itself.
#
# Previously maintained by Tels - (c) 2006 - 2008.
# Currently maintained by Slaven Rezic - (c) 2008 - 2023.

use strict;

our $VERSION = '1.44_50';

require Exporter;
*import = \&Exporter::import;

our @EXPORT_OK = qw(image_info dim html_dim image_type determine_file_format);

# already required and failed sub-modules are remembered here
my %mod_failure;

sub image_info
{
    my $source = _source(shift);
    return $source if ref $source eq 'HASH'; # Pass on errors

    # What sort of file is it?
    my $head = _head($source);

    return $head if ref($head) eq 'HASH';	# error?

    my $format = determine_file_format($head)
        or return { error => 'Unrecognized file format' };

    return _image_info_for_format($format, $source);
}

# Note: this function is private, but may be used by Image::Info::*
# implementations (i.e. the WBMP implementation)
sub _image_info_for_format
{
    my($format, $source) = @_;

    my $mod = "Image::Info::$format";
    my $sub = "$mod\::process_file";
    my $info = bless [], "Image::Info::Result";
    eval {
        unless (defined &$sub) {
	    # already required and failed?
            if (my $fail = $mod_failure{$mod}) {
                die $fail;
            }
            eval "require $mod";
            if ($@) {
                $mod_failure{$mod} = $@;
                die $@;
            }
            die "$mod did not define &$sub" unless defined &$sub;
        }

        my %cnf = @_;
        {
	    # call process_file()
	    no strict 'refs';
	    &$sub($info, $source, \%cnf);
	}
        $info->clean_up;
    };
    return { error => $@ } if $@;
    return wantarray ? @$info : $info->[0];
}

sub image_type
{
    my $source = _source(shift);
    return $source if ref $source eq 'HASH'; # Pass on errors

    # What sort of file is it?
    my $head = _head($source) or return _os_err("Can't read head");
    my $format = determine_file_format($head)
        or return { error => "Unrecognized file format" };

    return { file_type => $format };
}

# Note: this function is private, but may be used by Image::Info::*
# implementations (i.e. the WBMP implementation)
sub _source
{
    my $source = shift;
    if (!ref $source) {
	my $fh;
	if ($] < 5.006) {
	    require Symbol;	
	    $fh = Symbol::gensym();
	    open($fh, $source) || return _os_err("Can't open $source");
	}
	else {
	    open $fh, '<', $source
		or return _os_err("Can't open $source");
	}
	${*$fh} = $source;  # keep filename in case somebody wants to know
        binmode($fh);
        $source = $fh;
    }
    elsif (ref($source) eq "SCALAR") {
	# Earlier PerlIO::scalar versions may segfault or consume lots
	# of memory for some invalid images, see
	# RT #100847 and img/segfault.tif
	if (eval { require PerlIO::scalar; PerlIO::scalar->VERSION(0.21) } ||
	    !eval { require IO::Scalar; 1 }) {
	    open(my $s, "<", $source) or return _os_err("Can't open string");
	    $source = $s;
	}
	else {
	    $source = IO::Scalar->new($source);
	}
    }
    else {
	seek($source, 0, 0) or return _os_err("Can't rewind");
    }

    $source;
}

sub _head
{
    my $source = shift;
    my $head;

    # Originally was 32 bytes.
    # In the meantime lowered to 11 bytes.
    # But XBM probably need more because of a leading comment.
    my $to_read = 64;
    my $read = read($source, $head, $to_read);

    return _os_err("Couldn't read any bytes") if !$read;

    if (ref($source) eq "IO::String") {
	# XXX workaround until we can trap seek() with a tied file handle
	$source->setpos(0);
    }
    else {
	seek($source, 0, 0) or return _os_err("Can't rewind");
    }
    $head;
}

sub _os_err
{
    return { error => "$_[0]: $!",
	     Errno => $!+0,
	   };
}

sub determine_file_format
{
   local($_) = @_;
   return "JPEG" if /^\xFF\xD8/;
   return "PNG" if /^\x89PNG\x0d\x0a\x1a\x0a/;
   return "GIF" if /^GIF8[79]a/;
   return "TIFF" if /^MM\x00\x2a/;
   return "TIFF" if /^II\x2a\x00/;
   return "BMP" if /^BM/;
   return "ICO" if /^\000\000\001\000/;
   return "PPM" if /^P[1-6]/;
   return "XPM" if /(^\/\* XPM \*\/)|(static\s+char\s+\*\w+\[\]\s*=\s*{\s*"\d+)/;
   return "XBM" if /^(?:\/\*.*\*\/\n)?#define\s/;
   return "AVIF" if /\A....ftypavif/s;
   return "SVG" if /^(<\?xml|[\012\015\t ]*<svg\b)/;
   return "WEBP" if /^RIFF.{4}WEBP/s;
   return undef;
}

sub dim
{
    my $img = shift || return;
    my $x = $img->{width} || return;
    my $y = $img->{height} || return;
    wantarray ? ($x, $y) : "${x}x$y";
}

sub html_dim
{
    my($x, $y) = dim(@_);
    return "" unless $x;
    "width=\"$x\" height=\"$y\"";
}

#############################################################################
package Image::Info::Result;

sub push_info
{
    my($self, $n, $key) = splice(@_, 0, 3);
    push(@{$self->[$n]{$key}}, @_);
}

sub replace_info
{
    my($self, $n, $key) = splice(@_, 0, 3);
    $self->[$n]{$key}[0] = $_[0];
}

sub clean_up
{
    my $self = shift;
    for (@$self) {
	for my $k (keys %$_) {
	    my $a = $_->{$k};
	    $_->{$k} = $a->[0] if @$a <= 1;
	}
    }
}

sub get_info {
    my($self, $n, $key, $delete) = @_;
    my $v = $delete ? delete $self->[$n]{$key} : $self->[$n]{$key};
    $v ||= [];
    @$v;
}

1;

__END__

=head1 NAME

Image::Info - Extract meta information from image files

=head1 SYNOPSIS

 use Image::Info qw(image_info dim);

 my $info = image_info("image.jpg");
 if (my $error = $info->{error}) {
     die "Can't parse image info: $error\n";
 }
 my $color = $info->{color_type};
 
 my $type = image_type("image.jpg");
 if (my $error = $type->{error}) {
     die "Can't determine file type: $error\n";
 }
 die "No gif files allowed!" if $type->{file_type} eq 'GIF';
 
 my($w, $h) = dim($info);

=head1 DESCRIPTION

This module provides functions to extract various kinds of meta
information from image files.

=head2 EXPORTS

Exports nothing by default, but can export the following methods
on request:

	image_info
	image_type
	dim
	html_dim
	determine_file_type

=head2 METHODS

The following functions are provided by the C<Image::Info> module:

=over

=item image_info( $file )

=item image_info( \$imgdata )

=item image_info( $file, key => value,... )

This function takes the name of a file or a file handle as argument
and will return one or more hashes (actually hash references)
describing the images inside the file.  If there is only one image in
the file only one hash is returned.  In scalar context, only the hash
for the first image is returned.

In case of error, a hash containing the "error" key will be
returned.  The corresponding value will be an appropriate error
message.

If a reference to a scalar is passed as an argument to this function,
then it is assumed that this scalar contains the raw image data
directly.

The C<image_info()> function also take optional key/value style arguments
that can influence what information is returned.

=item image_type( $file )

=item image_type( \$imgdata )

Returns a hash with only one key, C<< file_type >>. The value
will be the type of the file. On error, sets the two keys
C<< error >> and C<< Errno >>.

This function is a dramatically faster alternative to the image_info
function for situations in which you B<only> need to find the image type.

It uses only the internal file-type detection to do this, and thus does
not need to load any of the image type-specific driver modules, and does
not access to entire file. It also only needs access to the first 11
bytes of the file.

To maintain some level of compatibility with image_info, image_type
returns in the same format, with the same error message style. That is,
it returns a HASH reference, with the C<< $type->{error} >> key set if
there was an error.

On success, the HASH reference will contain the single key C<< file_type >>,
which represents the type of the file, expressed as the type code used for
the various drivers ('GIF', 'JPEG', 'TIFF' and so on).

If there are multiple images within the file they will be ignored, as this
function provides only the type of the overall file, not of the various
images within it. This function will not return multiple hashes if the file
contains multiple images.

Of course, in all (or at least effectively all) cases the type of the images
inside the file is going to be the same as that of the file itself.

=item dim( $info_hash )

Takes an hash as returned from C<image_info()> and returns the dimensions
($width, $height) of the image.  In scalar context returns the
dimensions as a string.

=item html_dim( $info_hash )

Returns the dimensions as a string suitable for embedding directly
into HTML or SVG <img>-tags. E.g.:

   print "<img src="..." @{[html_dim($info)]}>\n";

=item determine_file_format( $filedata )

Determines the file format from the passed file data (a normal Perl
scalar containing the first bytes of the file), and returns
either undef for an unknown file format, or a string describing
the format, like "BMP" or "JPEG".

=back

=head1 Image descriptions

The C<image_info()> function returns meta information about each image in
the form of a reference to a hash.  The hash keys used are in most
cases based on the TIFF element names.  All lower case keys are
mandatory for all file formats and will always be there unless an
error occurred (in which case the "error" key will be present.)  Mixed
case keys will only be present when the corresponding information
element is available in the image.

The following key names are common for any image format:

=over

=item file_media_type

This is the MIME type that is appropriate for the given file format.
The corresponding value is a string like: "image/png" or "image/jpeg".

=item file_ext

The is the suggested file name extension for a file of the given file
format.  The value is a 3 letter, lowercase string like "png", "jpg".

=item width

This is the number of pixels horizontally in the image.

=item height

This is the number of pixels vertically in the image.  (TIFF uses the
name ImageLength for this field.)

=item color_type

The value is a short string describing what kind of values the pixels
encode.  The value can be one of the following:

  Gray
  GrayA
  RGB
  RGBA
  CMYK
  YCbCr
  CIELab

These names can also be prefixed by "Indexed-" if the image is
composed of indexes into a palette.  Of these, only "Indexed-RGB" is
likely to occur.

It is similar to the TIFF field "PhotometricInterpretation", but this
name was found to be too long, so we used the PNG inspired term
instead.

=item resolution

The value of this field normally gives the physical size of the image
on screen or paper. When the unit specifier is missing then this field
denotes the squareness of pixels in the image.

The syntax of this field is:

   <res> <unit>
   <xres> "/" <yres> <unit>
   <xres> "/" <yres>

The <res>, <xres> and <yres> fields are numbers.  The <unit> is a
string like C<dpi>, C<dpm> or C<dpcm> (denoting "dots per
inch/cm/meter).

=item SamplesPerPixel

This says how many channels there are in the image.  For some image
formats this number might be higher than the number implied from the
C<color_type>.

=item BitsPerSample

This says how many bits are used to encode each of samples.  The value
is a reference to an array containing numbers. The number of elements
in the array should be the same as C<SamplesPerPixel>.

=item Comment

Textual comments found in the file.  The value is a reference to an
array if there are multiple comments found.

=item Interlace

If the image is interlaced, then this tells which interlace method is
used.

=item Compression

This tells you which compression algorithm is used.

=item Gamma

A number.

=item LastModificationTime

A ISO date string

=back

=head1 Supported Image Formats

The following image file formats are supported:

=over


=item AVIF

Supports the basic standard info key names.

=item BMP

This module supports the Microsoft Device Independent Bitmap format
(BMP, DIB, RLE).

For more information see L<Image::Info::BMP>.

=item GIF

Both GIF87a and GIF89a are supported and the version number is found
as C<GIF_Version> for the first image.  GIF files can contain multiple
images, and information for all images will be returned if
image_info() is called in list context.  The Netscape-2.0 extension to
loop animation sequences is represented by the C<GIF_Loop> key for the
first image.  The value is either "forever" or a number indicating
loop count.

=item ICO

This module supports the Microsoft Windows Icon Resource format
(.ico).

=item JPEG

For JPEG files we extract information both from C<JFIF> and C<Exif>
application chunks.

C<Exif> is the file format written by most digital cameras. This
encode things like timestamp, camera model, focal length, exposure
time, aperture, flash usage, GPS position, etc.

The C<Exif> spec can be found at:
L<http://www.exif.org/specifications.html>.

The C<color_type> element may have the following values: C<Gray>,
C<YCbCr>, and C<CMYK>. Note that detecting C<RGB> and C<YCCK>
currently does not work, but will hopefully in future.

=item PNG

Information from IHDR, PLTE, gAMA, pHYs, tEXt, tIME chunks are
extracted.  The sequence of chunks are also given by the C<PNG_Chunks>
key.

=item PBM/PGM/PPM

All information available is extracted.

=item SVG

Provides a plethora of attributes and metadata of an SVG vector graphic.

=item TIFF

The C<TIFF> spec can be found at:
L<http://partners.adobe.com/public/developer/tiff/>

The EXIF spec can be found at:
L<http://www.exif.org/specifications.html>

=item WBMP

wbmp files have no magic, so cannot be used with the normal
Image::Info functions. See L<Image::Info::WBMP> for more information.

=item WEBP

VP8 (lossy), VP8L (lossless) and VP8X (extended) files are supported.
Sets the key C<Animation> to true if the file is an animation. Otherwise
sets the key C<Compression> to either C<VP8> or C<Lossless>.

=item XBM

See L<Image::Info::XBM> for details.

=item XPM

See L<Image::Info::XPM> for details.

=back

=head1 CAVEATS

While this module is fine for parsing basic image information like
image type, dimensions and color depth, it is probably not good enough
for parsing out more advanced information like EXIF data. If you want
an up-to-date and tested EXIF parsing library, please use
L<Image::ExifTool>.

=head1 SEE ALSO

L<Image::Size>, L<Image::ExifTool>

=head1 AUTHORS

Copyright 1999-2004 Gisle Aas.

See the CREDITS file for a list of contributors and authors.

Tels - (c) 2006 - 2008.

Current maintainer: Slaven Rezic - (c) 2008 - 2015.

=head1 LICENSE

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl v5.8.8 itself.

=cut

# Local Variables: 
# mode: cperl
# End: 
