package App::TimeTracker::Command::Category;
use strict;
use warnings;
use 5.010;

# ABSTRACT: use categories when tracking time with App::TimeTracker

our $VERSION = "1.001";

use Moose::Util::TypeConstraints;
use Moose::Role;

after '_load_attribs_start' => sub {
    my ( $class, $meta, $config ) = @_;

    my $cfg = $config->{category};
    return unless $cfg && $cfg->{categories};

    subtype 'ATT::Category'
        => as enum($cfg->{categories})
        => message {"$_ is not a valid category (as defined in the current config)"};

    $meta->add_attribute(
        'category' => {
            isa           => 'ATT::Category',
            is            => 'ro',
            required      => $cfg->{required},
            documentation => 'Category',
        } );
};

before [ 'cmd_start', 'cmd_continue', 'cmd_append' ] => sub {
    my $self = shift;

    $self->add_tag($self->category);
};

sub cmd_statistic {
    my $self = shift;

    my @files = $self->find_task_files( {
            from     => $self->from,
            to       => $self->to,
            projects => $self->fprojects,
            tags     => $self->ftags,
            parent   => $self->fparent,
        } );
    my $cats = $self->config->{category}{categories};

    my $total  = 0;
    my %stats;

    foreach my $file (@files) {
        my $task    = App::TimeTracker::Data::Task->load( $file->stringify );
        my $time    = $task->seconds // $task->_build_seconds;
        $total += $time;
        my %tags = map { $_=>1 } @{$task->tags};

        my $got_cat = 0;
        foreach my $cat (@$cats) {
            if ($tags{$cat}) {
                $stats{$cat}{abs} += $time;
                $got_cat=1;
                last;
            }
        }
        $stats{_no_cat}{abs}+=$time unless $got_cat;
    }

    while (my ($cat, $data) = each %stats) {
        $data->{percent} = sprintf("%.1f", $data->{abs} / $total * 100 );
        $data->{nice} =  $self->beautify_seconds($data->{abs});
    }

    $self->_say_current_report_interval;
    printf("%39s\n", $self->beautify_seconds($total));
    foreach my $cat (sort keys %stats) {
        my $data = $stats{$cat};
        printf("%6s%%  %- 20s% 10s\n",$data->{percent},$cat, $data->{nice});
    }
}

sub _load_attribs_statistic {
    my ( $class, $meta ) = @_;
    $class->_load_attribs_worked($meta);
}

no Moose::Role;
1;

__END__

=head1 DESCRIPTION

Define some categories, which act like 'Super-Tags', for example:
"feature", "bug", "maint", ..

=head1 CONFIGURATION

=head2 plugins

Add C<Category> to the list of plugins.

=head2 category

add a hash named C<category>, containing the following keys:

=head3 required

Set to a true value if 'category' should be a required command line option

=head3 categories

A list (ARRAYREF) of category names.

=head1 NEW COMMANDS

=head2 statistic

Print stats on time worked per category

    domm@t430:~/validad$ tracker statistic --last day
    From 2016-01-29T00:00:00 to 2016-01-29T23:59:59 you worked on:
                                   07:39:03
       9.9%  bug                   00:45:23
      33.2%  feature               02:32:21
      28.3%  maint                 02:09:52
      12.9%  meeting               00:59:21
      15.7%  support               01:12:06

You can use the same options as in C<report> to define which tasks you
want stats on (C<--from, --until, --this, --last, --ftag, --fproject,
..)

=head1 CHANGES TO OTHER COMMANDS

=head2 start, continue, append

=head3 --category

    ~/perl/Your-Project$ tracker start --category feature

Make sure that 'feature' is a valid category and store it as a tag.

