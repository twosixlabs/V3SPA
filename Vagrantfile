# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "fedora/24-cloud-base"
  config.vm.box_url = "http://archives.fedoraproject.org/pub/archive/fedora/linux/releases/24/CloudImages/x86_64/images/Fedora-Cloud-Base-Vagrant-24-1.2.x86_64.vagrant-virtualbox.box"

  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'

  config.ssh.insert_key=true

  config.vm.provider :virtualbox do |vb|
      vb.memory = 8192
      vb.cpus = 3
      vb.name = "v3spa_builder24"
  end

  #config.vm.synced_folder "./", "/home/vagrant/vespa/ide"

  config.vm.network :forwarded_port, guest: 8080, host: 8080

  config.vm.provision "shell", :privileged => false, inline: <<-SHELL
    sudo dnf install -y python git setools-devel setools-libs bzip2-devel bison flex nodejs python-tornado python-devel mongodb-server swig libsepol libsepol-devel libsepol-static libselinux-python libselinux-static redhat-rpm-config
    curl -sSL https://s3.amazonaws.com/download.fpcomplete.com/fedora/24/fpco.repo | sudo tee /etc/yum.repos.d/fpco.repo
    sudo dnf -y install zlib-devel stack
    sudo pip install --upgrade pip
    sudo pip install virtualenv networkx setuptools
    cd /vagrant
    git submodule update --init
    sudo npm install -g gulp
    sudo npm install
    virtualenv vespa
    source vespa/bin/activate
    pip install -r requirements.txt
    gulp

    cd lobster
    make

    cd /home/vagrant/
    mkdir vespa
    cd vespa

    mkdir /home/vagrant/vespa/lobster
    cp /vagrant/lobster/v3spa-server/dist/bin/* /home/vagrant/vespa/lobster/

    git clone https://github.com/TresysTechnology/setools.git
    cd setools
    git checkout 4.0.0
    sudo python setup.py install

    cd /home/vagrant/vespa
    mkdir mongodb
    mkdir tmp
    mkdir tmp/bulk
    mkdir tmp/bulk/log
    mkdir tmp/bulk/refpolicy
    mkdir tmp/bulk/tmp
    mkdir tmp/bulk/projects

    cd /home/vagrant/vespa/setools
    sudo python setup.py install

  SHELL

  config.vm.provision "shell", run: 'always', inline: <<-SHELL
    ps cax | grep mongod > /dev/null
    if [ $? -eq 1 ]; then
      cd /home/vagrant/vespa
      nohup mongod --dbpath ./mongodb & sleep 1
    else
      echo "Mongo is already running."
    fi

    ps cax | grep python > /dev/null
    if [ $? -eq 1 ]; then
      cd /vagrant
      git submodule update --init
      sudo npm install -g gulp
      sudo npm install
      virtualenv vespa
      source vespa/bin/activate
      pip install -r requirements.txt
      gulp
      cd /home/vagrant/vespa
      nohup python /vagrant/vespa.py & sleep 1
    else
      echo "V3SPA is already running."
    fi

    ps cax | grep v3spa-server > /dev/null
    if [ $? -eq 1 ]; then
      cd /home/vagrant/vespa
      cd tmp/bulk
      nohup /home/vagrant/vespa/lobster/v3spa-server & sleep 1
    else
      echo "Lobster is already running."
    fi
  SHELL

end
