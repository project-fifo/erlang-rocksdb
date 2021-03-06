Vagrant.configure("2") do |config|

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 2
    v.customize ["modifyvm", :id, "--hwvirtex", "on"]
    v.customize ["modifyvm", :id, "--audio", "none"]
    v.customize ["modifyvm", :id, "--nictype1", "virtio"]
    v.customize ["modifyvm", :id, "--nictype2", "virtio"]
  end

  config.vm.define "ubuntu16" do |box|
    box.vm.box = "ubuntu/xenial64"
    box.vm.network "private_network", type: "dhcp"

    box.vm.provision "shell", inline: <<-SCRIPT
        wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
        sudo dpkg -i erlang-solutions_1.0_all.deb
        sudo apt-get update
        sudo apt-get -y install libgflags-dev build-essential curl esl-erlang
        cd /vagrant
        ./support/rebar3 compile
    SCRIPT

  end

  config.vm.define "freebsd10" do |box|
    box.vm.guest = :freebsd
    box.vm.box = "freebsd/FreeBSD-10.3-STABLE"
    box.vm.synced_folder ".", "/vagrant", :nfs => true, id: "vagrant-root"
    box.vm.network "private_network", type: "dhcp"
    box.ssh.shell = "sh"

    # build everything after creating VM, skip using --no-provision
    box.vm.provision "shell", inline: <<-SCRIPT
      pkg install -y gmake gflags vim gcc48 erlang
    SCRIPT

  end

end
