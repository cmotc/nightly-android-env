#! /bin/sh

USE_DEBSH_SCRIPTS="Y"
USE_RPMSH_SCRIPTS="Y"
USE_DROIDSH_SCRIPTS="Y"
if [ "$1" == "no-scripts" ]; then
	USE_DEBSH_SCRIPTS="N"
	USE_RPMSH_SCRIPTS="N"
	USE_DROIDSH_SCRIPTS="N"
fi

WORKDIR=$(pwd)

echo "Loading build helper scripts in $WORKDIR"

#clean up everything but unfinished folders
clean(){
	cd $WORKDIR
	rm *.build *.dsc *.tar.xz *.deb *.*.tar.xz *.changes *.tar.gz
	rm log
}

#clean up everything including unfinished folders
clobber(){
	cd $WORKDIR
	clean
	for d in *; do
		day=$(date +%Y%m%d)
		until [[ $day == *00 ]]; do
			rm -rf $d-$day 2> /dev/null
			((day--))
		done
	done
}

#clean up everything but the built packages
dustup(){
	cd $WORKDIR
	for d in *; do
		day=$(date +%Y%m%d)
		until [[ $day == *00 ]]; do
			rm -rf $d-$day 2> /dev/null
			((day--))
		done
	done
}

#Helper for building debian packages with no alterations
deb_nosh(){
	d="$1"
	echo "$d/debian.sh file not found. Attempting to build package automatically."
	DEBFOLDERNAME="$d""_"$(date +%Y%m%d)
	cd "$d" && git pull && cd ..
	cp -Rv "$d" $DEBFOLDERNAME
	tar -czvf $DEBFOLDERNAME.orig.tar.gz $DEBFOLDERNAME
	t="false"
	cd $DEBFOLDERNAME && t="true" && debuild -us -uc >> ../log
	cd $WORKDIR
}
#Helper for building redhat packages with no alterations
rpm_nosh(){
	d="$1"
	echo "I don't know how to build rpm packages yet so $d.rpm does not build. Skipping and proceeding normally."
	cd $WORKDIR
}

#Helper for building android packages with no alterations
droid_nosh(){
	d="$1"
	echo "I don't know how to build rpm packages yet so $d.apk does not build. Skipping and proceeding normally."
	cd $WORKDIR
}

#build all packages in all subdirectories
build(){
	cd $WORKDIR
	clean
	alias dh_make="dh_make --yes"
	if [ "$1" != ""]; then
		if [ "$1" != "upload" ]; then
			d="$1"
			if [ -f "$d/debian.sh" ]; then
				if [ "$USE_DEBSH_SCRIPTS" = "Y" ]; then
					. "$d/debian.sh" && echo "<<<Built $DEBFOLDERNAME>>>" && rm -rf $DEBFOLDERNAME 
					cd $WORKDIR
				fi
			else
				if [ -d "$d/debian" ]; then
					deb_nosh "$d"
				fi
			fi
			if [ -f "$d/rpm.sh" ]; then
				if [ "$USE_RPMSH_SCRIPTS" = "y" ]; then
					. "$d/rpm.sh" && echo "<<<Built $RPMFOLDERNAME>>>" && rm -rf $RPMFOLDERNAME #&& cd ..
					cd $WORKDIR
				fi
			else
				if [ -f "$d/*.spec"]; then
					rpm_nosh "$d"
				fi
			fi
			if [ -f "$d/droid.sh" ]; then
				if [ "$USE_DROIDSH_SCRIPTS" = "y" ]; then
					. "$d/rpm.sh" && echo "<<<Built $DROIDFOLDERNAME>>>" && rm -rf $DROIDFOLDERNAME #&& cd ..
					cd $WORKDIR
				fi
			else
				droid_nosh "$d"
			fi
		fi
	else
		for d in *; do
			if [ -f "$d/debian.sh" ]; then
				if [ "$USE_DEBSH_SCRIPTS" = "Y" ]; then
					. "$d/debian.sh" && echo "<<<Built $DEBFOLDERNAME>>>" && rm -rf $DEBFOLDERNAME 
					cd $WORKDIR
				fi
			else
				if [ -d "$d/debian" ]; then
					deb_nosh "$d"
				fi
			fi
			if [ -f "$d/rpm.sh" ]; then
				if [ "$USE_RPMSH_SCRIPTS" = "y" ]; then
					. "$d/rpm.sh" && echo "<<<Built $RPMFOLDERNAME>>>" && rm -rf $RPMFOLDERNAME #&& cd ..
					cd $WORKDIR
				fi
			else
				if [ -f "$d/*.spec"]; then
					rpm_nosh "$d"
				else
					echo "Not enough information to build .rpm package"
				fi
			fi
			if [ -f "$d/droid.sh" ]; then
				if [ "$USE_DROIDSH_SCRIPTS" = "y" ]; then
					. "$d/rpm.sh" && echo "<<<Built $DROIDFOLDERNAME>>>" && rm -rf $DROIDFOLDERNAME #&& cd ..
					cd $WORKDIR
				fi
			else
				droid_nosh "$d"
			fi
		done
	fi
	if [ "$1" = "upload" ] ; then
		upload
	fi
}

#Pull down all the updates from the source repositories.
update(){
        cd $WORKDIR
	for d in *; do
		if [ -d "$d/.git" ]; then
			cd $d
			git pull origin master
			cd $WORKDIR
		fi
        done
}

#Sign and update packages in remote repository
upload(){
	cd $WORKDIR
	rm -rf ../repository/packages/
	mkdir -p ../repository/packages/
	cp *.build *.changes *.tar.xz *.dsc *.deb ../repository/packages/
	if [ ! -d ../repository ]; then
		genrepo
	fi
	cd $WORKDIR
	cd ../repository/
	rm -rf debian
	./apt-git --check
}

#generate regeneration script
genclone(){
	cd $WORKDIR
	GLOBIGNORE=.
	echo "#! /bin/sh" > ./.clone
	for subdir in *; do
		test -d "$subdir" || continue
		cd "$subdir"
		remote=$(git remote -v)
		for word in $remote; do
			if [ `echo "$word" | grep 'git@' ` ]; then
				echo "git clone $word" >> ../clone-$(date +%Y%m%d)
			fi
		done
		cd -
	done
	awk '!seen[$0]++' ./clone-$(date +%Y%m%d) > ./.clone
	rm ./clone-$(date +%Y%m%d)
	chmod a+x ./.clone
}

clone(){
	cd $WORKDIR
	./.clone
	for d in *; do
		if [ -f "$d/gitrepos.sh" ]; then
			cd $d
			./gitrepos.sh
			cd $WORKDIR
		fi
	done
}

force_update(){
	cd $WORKDIR
	for d in *; do
		if [ -d "$d/.git" ]; then
			cd $d && git pull
			cd $WORKDIR
		fi
	done
}

force_sub_update(){
	cd $WORKDIR
	for d in *; do
		if [ -d "$d/.git" ]; then
			cd $d && git commit -am "$(date)"
			git push --set-upstream origin master
			cd $WORKDIR
		fi
	done
}

#generate a repository.
genrepo(){ 
#	This command should be able to generate a repository for upload.
#	Right now I'm just using apt-git, which is just a little hack I use to
#	host a few debian packages on github pages. apt-git's probably going to
#	become pkg-git when it can also structure other types of repositories.
#	Besides that, it should also be able to do other things, like with aptly
#	and all the other tools for automatically structuring repositories. This
#	needs to be done in part to remove dependencies on github itself.
#	Bitbucket has a similar setup which is cool, but the fewer proprietary
#	dependencies the better and that means self hosting. Which is easy
#	because they're just https servers which means you can shoehorn one into
#	pretty much anything that'll give you the space to do it. Which makes
#	this all a little daunting, because my whole goal is to make this system
#	even more approachable, customizable, and decentralized and all those
#	options leave the definition of those terms open to interpretation.
	cd $WORKDIR
        git clone git@github.com:cmotc/fdroid-git.git ../repository
#	git clone https://www.github.com/cmotc/apt-git/apt-git.git ../repository
#	git clone https://www.github.com/$HOSTID/apt-git/apt-git.git ../repository
}
