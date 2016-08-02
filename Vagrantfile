# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "fedora/24-cloud-base"

  config.ssh.username = 'vagrant'
  config.ssh.password = 'vagrant'

  config.ssh.insert_key=true

  config.vm.provider :virtualbox do |vb|
      vb.memory = 4096
      vb.cpus = 2
      vb.name = "v3spa_builder24"
  end

  #config.vm.synced_folder "./", "/home/vagrant/vespa/ide"

#     sudo dnf install git swig libsepol libsepol-devel libsepol-static redhat-rpm-config setools-devel bzip2-devel gcc bison flex nodejs npm python-tornado python-pip python-devel mongodb-server -y

  config.vm.network :forwarded_port, guest: 8080, host: 8080
  #config.vm.provision :shell, :privileged => false, :path => "bootstrap.sh"
#   config.vm.provision "shell", :privileged => false, inline: <<-SHELL
#     sudo dnf install -y python git setools-devel setools-libs bzip2-devel bison flex nodejs python-tornado python-devel mongodb-server swig libsepol libsepol-devel libsepol-static redhat-rpm-config
#     curl -sSL https://s3.amazonaws.com/download.fpcomplete.com/fedora/24/fpco.repo | sudo tee /etc/yum.repos.d/fpco.repo
#     sudo dnf -y install zlib-devel stack
#     sudo pip install virtualenv networkx setuptools
#     cd /vagrant
#     git submodule update --init
#     sudo npm install -g gulp
#     sudo npm install
#     virtualenv vespa
#     source vespa/bin/activate
#     pip install -r requirements.txt
#     gulp

#     cd lobster
#     make

#     cd /home/vagrant/
#     mkdir vespa
#     cd vespa

#     git clone https://github.com/TresysTechnology/setools.git
#     cd setools
#     git checkout 4.0.0
#     sudo python setup.py install

#     cd /home/vagrant/vespa
#     mkdir mongodb
#     mkdir tmp
#     mkdir tmp/bulk
#     mkdir tmp/bulk/log
#     mkdir tmp/bulk/refpolicy
#     mkdir tmp/bulk/tmp
#     mkdir tmp/bulk/projects
#     mongod --dbpath ./mongodb &

#     python /vagrant/vespa.py &

#     (cd tmp/bulk && /vagrant/ide/lobster/v3spa-server/dist/v3spa-server) &

#   SHELL

  # config.vm.provision "shell", :privileged => false, inline: <<-SHELL
  #   cd /home/vagrant/vespa
  #   sudo dnf install gcc nodejs npm python-tornado python-pip git python-devel mongodb-server -y
  #   sudo pip install virtualenv
  #   mkdir vespa && cd vespa
  #   git init
  #   cd ide
  #   git submodule update --init
  #   sudo npm install -g gulp
  #   sudo npm install
  #   virtualenv vespa
  #   source vespa/bin/activate
  #   pip install -r requirements.txt
  #   gulp
  #   cd ~/vespa/
  #   mkdir mongodb

  # SHELL

end
