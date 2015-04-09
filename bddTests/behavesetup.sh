if ! which behave
then
    echo "behave not found, installing via easy_install"
	userID=`whoami`
	curl https://bootstrap.pypa.io/ez_setup.py -o - | python
	curl https://bootstrap.pypa.io/ez_setup.py -o - | python
	curl https://bootstrap.pypa.io/ez_setup.py > ez_setup.py 
	chmod ez_setup.py 
	chmod +x ez_setup.py 
	./ez_setup.py --install-dir . 
	./ez_setup.py --help 
	./ez_setup.py --user jenkins
	easy_install 
	easy_install install behave --user $userID
	pushd .
	cd 
	find . | grep easy 
	cd .local/bin/
	ls
	./easy_install-2.7 install behave 
	./easy_install-2.7 behave 
	ls
	behaveDir="`pwd`"
	PATH=$PATH:$behaveDir
	echo "PATH"
	echo $PATH
	export PATH
	popd
fi