require "vboxmanage/version"
require "net/ssh"

module Vboxmanage
  VBOX='/usr/bin/vboxmanage'
  VBOXH='/usr/bin/VBoxHeadless'
  log=""


 def vmList
    machine = Hash.new
    %x("#{VBOX}" list vms|sed 's/{//g'|sed 's/}//g'|sed 's/"//g').each_line do |l|
   (name,id) = l.split(/\s+/,2)
   machine[name] = id.chomp
  end
  return machine
 end

  def vmExists?(name)
    machines = vmList()
    if machines.has_key?(name)
      return machines[name]
    end
  end

  def vmStart(name)
    p1 = fork { exec("#{VBOXH} --startvm #{name}") }
    Process.detach(p1)
    id = vmExists?(name)
    puts "Started #{name}"
  end

  def vmState(name)
    state = Hash.new
    %x("#{VBOX}" showvminfo "#{name}" --details --machinereadable).each_line do |l|
      (key,value) = l.split(/\=/,2)
      nv = value.gsub(/"/, '')
      state[key] = nv.chomp
    end
  return state
  end

  def vmRunning?(name)
    state = vmState(name)
    if state['VMState'].eql?("running")
      puts true
    else
      puts false
    end
  end

  def vmCreate(name,dest,image, cpu, memory)
    log=""
    if vmExists?(name) 
      puts "#{name} vm already exists aborting"
      exit 1
    end     
    #VBoxManage clonemedium disk /vms/image_build/centos7/output-virtualbox-iso/centos7-base-0.1.0-disk001.vmdk  /vms/${VM}/${VM}.vdi --format VDI
    puts "Cloning Device"
    log << %x("#{VBOX}" clonemedium disk  "#{image}" "#{dest}/#{name}/#{name}.vdi" --format VDI)
    puts "Creating VM"
    log << %x("#{VBOX}" createvm --name "#{name}" --register)
    puts  "Set Mem"
    log << %x("#{VBOX}" modifyvm "#{name}" --memory "#{memory}")
    puts "Set CPU"
    log << %x("#{VBOX}" modifyvm "#{name}" --cpus "#{cpu}")
    log << %x("#{VBOX}" modifyvm "#{name}" --ioapic on)
    log << %x("#{VBOX}" modifyvm "#{name}" --nic1 bridged --bridgeadapter1 eno1 --nictype1 virtio --cableconnected1 on)
    log << %x("#{VBOX}" modifyvm "#{name}" --macaddress1 auto)
    log << %x("#{VBOX}" modifyvm "#{name}" --ostype RedHat_64)
   # log << %x("#{VBOX}" modifyvm "#{name}" --audio alsa)
    log << %x("#{VBOX}" storagectl "#{name}" --name "SATA Controller" --add sata)
    log << %x("#{VBOX}" modifyvm "#{name}" --macaddress1 auto)
    log << %x("#{VBOX}" storageattach "#{name}" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "#{dest}/#{name}/#{name}.vdi")
    log << %x("#{VBOX}" createhd --filename "#{dest}/#{name}/#{name}-app.vdi" --size 20)
    log << %x("#{VBOX}" storageattach "#{name}" --storagectl "SATA Controller" --port 1 --device 0 --type hdd --medium "#{dest}/#{name}/#{name}-app.vdi")
    vmStart(name)
    until vmAvail('root', name)
      do
        printf "."
      end
  end


  def vmAvail(user, name)
    puts "SSHing #{host} ..."
    Net::SSH.start( host.to_s, user.to_s, :password => pass.to_s ) do |ssh|
      puts ssh.exec!('date')
      puts "Logging out..."
    end
  end

  def vmStop(name)
    uuid = vmExists?(name)
    %x("#{VBOX}" controlvm "#{uuid}" poweroff)
  end


  def vmDestroy(name)
     vmStop(name)
     uuid = vmExists?(name)
     %x("#{VBOX}" unregistervm "#{uuid}" --delete)
  end

end
