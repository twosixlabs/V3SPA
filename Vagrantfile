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

  config.vm.network :forwarded_port, guest: 8080, host: 8080
  #config.vm.provision :shell, :privileged => false, :path => "bootstrap.sh"
  config.vm.provision "shell", :privileged => false, inline: <<-SHELL
    sudo dnf install gcc nodejs npm python-tornado python-pip git python-devel mongodb-server -y
    sudo pip install virtualenv
    cd /vagrant
    git submodule update --init
    sudo npm install -g gulp
    sudo npm install
    virtualenv vespa
    source vespa/bin/activate
    pip install -r requirements.txt
    gulp

    cd /home/vagrant/
    mkdir vespa
    cd vespa
    mkdir mongodb
    mkdir tmp
    mkdir tmp/bulk
    mkdir tmp/bulk
    mkdir tmp/bulk/log
    mkdir tmp/bulk/refpolicy
    mkdir tmp/bulk/tmp
    mkdir tmp/bulk/projects
    mongod --dbpath ./mongodb &

  SHELL

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
