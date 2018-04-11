#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use File::Basename;
use Getopt::Long;
use HTML::Template;
use Cwd 'abs_path';
#liangfan@nextomics.org
#use HTML::Embperl;
die "perl $0  <result_dir> <config_file> <outdir>\n" unless(@ARGV==3);
my $result_dir=shift;
my $config_file=shift;
my $outdir=shift;
my $figure_table_relation_file='file.list';
$result_dir=abs_path($result_dir);
$outdir=abs_path ($outdir);
our %media;
our %config;
our %html_TMPL_VAR_NAME;
our %html_TMPL_VAR_NAME_table;
our %html_TMPL_VAR_NAME_content;
die "$result_dir or $outdir is not exists\n" if(!-d $result_dir || !-d $outdir);
&read_relation_file($figure_table_relation_file);
&read_config_file($config_file);
&creat_out_put_dir($outdir);
&get_image($result_dir,$outdir);
#print Dumper \%html_TMPL_VAR_NAME_table;
&merge_hash(\%html_TMPL_VAR_NAME_table,\%html_TMPL_VAR_NAME);
&creat_new_html($outdir);

sub read_relation_file{
	my $file=shift;
	open IN,$file;
	while(<IN>){
		chomp;
		my @temp=split;
		next if($#temp!=2);
		push @{$media{$temp[0]}},($temp[1],$temp[2]);
	}
	close IN;
}
sub creat_new_html{
	my $outdir=shift;
	my $htmltemplate=$config{'htmlTemplate'};
	my $main_html=HTML::Template->new(filename => "$htmltemplate/index.html");
	foreach my $templ_var_name_content(keys %html_TMPL_VAR_NAME_content){
		print "index\t$templ_var_name_content\n";
		$main_html->param($templ_var_name_content=>$html_TMPL_VAR_NAME_content{$templ_var_name_content});
	}
	open OUT,">$outdir/index.html";
#	print OUT "Content-Type: text/html\n\n", $main_html->output;
	print OUT $main_html->output();
	close OUT;
	my $resultanalysis_html=HTML::Template->new(filename => "$htmltemplate/main.html");
	foreach my $templ_var_name(keys %html_TMPL_VAR_NAME){
		$resultanalysis_html->param($templ_var_name=>$html_TMPL_VAR_NAME{$templ_var_name});
    }
	open OUT,">$outdir/main.html";
	print OUT $resultanalysis_html->output();
	close OUT;
	
	

}
sub read_config_file{
	my $config_file=shift;
	open IN,$config_file;
	my $control=0;
	while(<IN>){
		chomp;
		next if(/^$/);
		if(/^#/){
			$control++;
			next;
		}else{
			my @temp=split /=/;
			if($control>0){
				$html_TMPL_VAR_NAME{$temp[0]}=$temp[1];
				if($control==1){
					$html_TMPL_VAR_NAME_content{$temp[0]}=$temp[1];
				}
			}else{
				$config{$temp[0]}=$temp[1];
			}
		}

	}
	close IN;
}
sub check_result{
	my $folds_p=shift;
	my %hash;
	foreach my $fold(@$folds_p){
		$hash{$fold}=1;
	}
	#my @issue=('01_Isoseq','02_NGS');
	my @issue=('01_Isoseq');
	foreach my $issue(@issue){
		if(!exists $hash{$issue}){
			die "please check your result directory, $issue is not exists!\n";
		}
	}
}
sub creat_out_put_dir{
	my $outdir=shift;
	&check_dir("$outdir/images");
	system ("cp -r $config{'htmlTemplate'}/* $outdir/");
#	print "cp -r $config{'htmlTemplate'}/* $outdir/\n";
}
sub check_dir{
    my $dir=shift;
    if(!-d $dir){
#        system ("mkdir $dir");
    }else{
#        die "$dir is exists, we will not override it\n";
    }
}
sub get_image{
	my $resultdir=shift;
	my $outputdir=shift;
	my @folder=`ls $resultdir`;
	chomp @folder;
	&check_result(\@folder);
	foreach my $image(keys %media){
		my $file="$resultdir/$image";
#		print $file,"\n";
		my $destination=$media{$image}->[0];
		#	next if($destination!~/Figure/);
		my $type=$media{$image}->[1];
		if($destination=~/Figure/){
			if($type eq 'M'){
				my @file=`ls $file`;
				chomp @file;
				my @basename_file;
				foreach my $image_unit (@file){
					my $basename_file=basename ($image_unit);
#					print "$image_unit\t$basename_file\n";
					my $basename_png=$basename_file;
					$basename_png=~s/\.\w+?$/.png/ if($basename_png!~/png$/);
#					print "$basename_file\t$basename_png\n";
					push @basename_file,$basename_png;
					&cp_image($image_unit,$basename_png,$outputdir);
				}
				#$file=$file[0];
#				print @basename_file,"\n";
				my $multi_image_content = &create_multi_image(\@basename_file);
				$html_TMPL_VAR_NAME_table{$destination}=$multi_image_content;
			}else{
				&cp_image($file,"$destination.png",$outputdir);
			}
#			print "$file\t$destination\t$outputdir\n";
		}elsif($destination=~/table/){
			&get_table($file,$destination,$type);
		}
	}
}
sub cp_image{
	my $image_file=shift;
	my $outname=shift;
	my $outputdir=shift;
	if(!-f $image_file){
		print "$image_file is not exists\n";
	}else{
#		print "cp $image_file $outputdir/static/media/\n";
		system ("cp $image_file $outputdir/static/media/");
#		print "cp $images[0] $outputdir/images/image/\n";
		&convert_to_png($image_file,"$outputdir/static/media/$outname");
	}
}
#	&get_table("$resultdir/DiffExpressionGene/","stat.xls","DiffExp","H");
#}
sub get_table{
	my $table_file=shift;
	my $html_var_name=shift;
	my $where_is_header=shift;
	$html_TMPL_VAR_NAME_table{$html_var_name}=&xls_convert_html($table_file,$where_is_header);
	
}
sub xls_convert_html{
	my $xls=shift;
	my $where_is_header=shift;
	open IN,$xls;
	print $xls,"\n";
	my $html;
	my $num=0;
	my $cut=0;
	if($where_is_header eq "M"){
		$cut=6;
	}
	$html='<div class="content_table">'."\n".'<table class="table table-bordered table-striped table-hover" >'."\n";
	while(<IN>){
		$num++;
		last if($num>$cut && $cut!=0);
		my @temp=split /\t/;
		my $last_unit;
			for(my $i=0;$i<=$#temp;$i++){
				if($num==1){
					if($i==0){
						$html.="<thead>\t<tr>\n\t\t<th><b>$temp[$i]</b></th>\n";	
					}elsif($i==$#temp){
						$html.="\t\t<th><b>$temp[$i]</b></th>\n</tr>\n</thead>\n<tbody>\n";
					}else{
						$html.="\t\t<th><b>$temp[$i]</b></th>\n";
					}
				}else{
					if($i==0){
						$html.="\t<tr>\n\t\t<td>$temp[$i]</td>\n";
					}elsif($i==$#temp){
						$html.="\t\t<td>$temp[$i]</td>\n</tr>\n";
					}else{
						$html.="\t\t<td>$temp[$i]</td>\n";
					}
				}
			}
	}
	$html.="\t".'</tbody>'."\n".'</table>'."\n".'</div>'."\n";
	return $html;

#	<tr>
#		<th><b>content</b></th>
#		<th><b>content</b></th>
#	</tr>
}
sub convert_to_png{
	my $file=shift;
	my $newfile=shift;
	my $base_name=basename($file);
	my $dir_name=dirname($newfile);
	if($file=~/png$/){
		my $tag1="$dir_name/$base_name";	
		my $tag2=$newfile;
		$tag1=~s/\S\+\///g;
		$tag2=~s/\S\+\///g;
		if($tag1 ne $tag2){
			system ("mv $dir_name/$base_name $newfile");
		}
	}else{
		system ("convert $dir_name/$base_name $newfile");
		system ("rm $dir_name/$base_name");
	}
}
sub merge_hash{
	my $hash1_p=shift;
	my $hash2_p=shift;
	foreach my $key(keys %$hash1_p){
		$hash2_p->{$key}=$hash1_p->{$key};
	}
}
sub create_multi_image{
	my $file_list=shift;
	my $multi_image_html='             <h6></h6>
	<div class="ad-gallery">
					<div class="ad-image-wrapper"></div>
					<div class="ad-controls"><input class="ad-slideshow-controls" placeholder="输入名称查询" oninput="genescarh($(this))"></div>
					<div class="ad-nav">
						<div class="ad-thumbs">
						<ul class="ad-thumb-list">
';
	foreach my $image(@$file_list){
		$multi_image_html.='							<li>
							<a href="static/media/'."$image".'">
								<img src="static/media/'."$image".'">
							</a>
							</li>
'
	}
	$multi_image_html.='						</ul>
						</div>
					</div>
				</div>
';
	return $multi_image_html;
}
