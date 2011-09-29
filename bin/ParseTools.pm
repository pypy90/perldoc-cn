package ParseTools;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw<>;
our @EXPORT_OK=qw< dict2hash hash2dict array2hash array2file
                   split2sentence filter_conceal_string >;
our @VERSION = 1.00;

use strict;
use warnings;
use 5.010;
use autodie;
use File::Slurp qw< read_file write_file>;
use List::MoreUtils qw< mesh uniq >;
use Lingua::Sentence;

# 字典转换成散列 my $ref_dict_hash = dict2hash($file1, $file2);
sub dict2hash {
    my @filelist = @_;
    my %dict_hash;
    foreach my $file (@filelist) {
        my @lines = read_file($file, binmode => ':utf8');
        foreach my $line (@lines) {
            chomp $line;
            $line =~ s/\r//;
            if ($line =~ /\|\|/) {
                my ($key, $value) = split /\|\|/, $line;
                $dict_hash{$key} = $value;
            }
        }
    }
    return \%dict_hash;
}

# 将字符串数组转换成映射字符散列
sub array2hash {
    my $ref_array = shift;
    my @array = uniq @{$ref_array};
    my $number = scalar @array;
    my @conceal = map { sprintf("&&%0.4x", $_) } (1 .. $number);
    # 合并两个数据类型相同的数组
    my %array2hash = mesh @array, @conceal;
    return \%array2hash;
}

# 将一个数组拆分成按照句子的数组
sub split2sentence {
    my @array = @_;
    my $splitter = Lingua::Sentence->new("en");
    my @split = map { $splitter->split_array($_) } @array;
    return @split;
}

# 将散列保存为字典文件 hash2dict(\%hash, $dict_name);
sub hash2dict {
    my ($ref_hash, $filename) = @_;
    my %dict_hash = %{$ref_hash};
    my $text;
    foreach my $key (sort keys %dict_hash) {
        my $value = $dict_hash{$key};
        $text .= "$key||$value\n";
    }
    write_file($filename, { binmode => ':utf8' }, $text);
    return 1;
}

# 数组写到文件，每行之间空一行
sub array2file {
    my ($ref_array, $file) = @_;
    my @array = @{$ref_array};
    my $last_line = '';
    open (my $fh_array2file, '>', $file);
    foreach my $line (@array) {
        chomp $line;
        # 如果是代码行，则不需要插入空行
        say {$fh_array2file} "\n" unless ($last_line =~ /^\s+/);
        say {$fh_array2file} $line;
        $last_line = $line;
    }
    close $fh_array2file;
    return 1;
}

# 将Pod文档中的不需要翻译的字符串数组提取成数组
sub filter_conceal_string {
    my $file  = shift;
    my $text  = read_file $file;
    my @lines = read_file $file;
    my (@head, @double_format, @format, @code);
    # 获取 =head =over =item 等结构数组
    @head = $text =~ /^=\w+/xmsg;

    # 获取每行前有空格的代码原文格式数组
    @code = grep { chomp; /^\s{1,}/ } @lines;
    # 替换掉注释
    foreach my $element (@code) {
        $element =~ s/#.*//;
    }

    # 中间替换变量
    my $elt = "\x{2264}"; # E<lt> => $elt
    my $egt = "\x{2265}"; # E<gt> => $egt
    my $lt  = "\x{226e}"; # '<' => $lt 
    my $gt  = "\x{226f}"; # '>' => $gt
    @double_format = $text =~ /[BCFILSX]<<+\s.*?\s>>+/mg;

    # 先将文本中的转义字符串替换掉
    $text =~ s/E<lt>/$elt/g;
    $text =~ s/E<gt>/$egt/g;
    while (1) {
        my @array = $text =~ /[BCFILSX]<[^<>]+>/mg;
        last if (scalar @array == 0);
        $text =~ s/([BCFILSX])<([^<>]+)>/$1$lt$2$gt/mg;
        push @format, @array;
    }
    # 恢复替换结果
    my @all_format = (@double_format, @format);
    uniq @all_format;
    foreach (@all_format) {
       $_ =~ s/$elt/E<lt>/g;
       $_ =~ s/$egt/E<gt>/g;
       $_ =~ s/$lt/</g;
       $_ =~ s/$gt/>/g;
       $_ =~ s/\n/ /g;
   }
   my @return_array = (@head, @code, @all_format);
   return \@return_array;
}

1;