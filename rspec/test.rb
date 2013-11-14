#!/usr/bin/env ruby
require 'rspec'

TMPDIR=%x(mktemp -d).strip
BASEREPO="#{TMPDIR}/base"
CRYPTREPO="#{TMPDIR}/crypt"
CRYPTREPO2="#{TMPDIR}/crypt2"
DECRYPTREPO="#{TMPDIR}/decrypt"

FILE1="file1"
DATA1="123\n321\n555\nabcdef"

FILE2="file2"
DATA2="asd\nefg\nzxc\nqwerty"

describe "Preparing git repo" do

    it "creating simple repo" do
        %x(
            mkdir -p #{BASEREPO}
            pushd #{BASEREPO}
            git init
            echo -e "#{DATA1}" >> #{FILE1}
            echo -e "#{DATA2}" >> #{FILE2}
            git add "#{FILE1}" "#{FILE2}"
            git commit -am "commit"
        )
        File.read(BASEREPO+"/"+FILE1).strip.should eq DATA1
        File.read(BASEREPO+"/"+FILE2).strip.should eq DATA2
    end

    it "creating crypted repo" do
        %x(
            pushd #{TMPDIR}
            git clone #{BASEREPO} #{CRYPTREPO}
        )
        File.read(CRYPTREPO+"/"+FILE1).strip.should eq DATA1
        File.read(CRYPTREPO+"/"+FILE2).strip.should eq DATA2

        %x(
            pushd #{CRYPTREPO}
            echo "\nn\npasswd\n\n\n\n#{FILE1}\n" | gitcrypt init
            git reset --hard
        )
        File.read(CRYPTREPO+"/"+FILE1).strip.should eq ""
        File.read(CRYPTREPO+"/"+FILE2).strip.should eq DATA2
    end

    it "crypting repo history" do
        %x(
            pushd #{CRYPTREPO}
            echo "y\n" | gitcrypt crypthistory
        )
        File.read(CRYPTREPO+"/"+FILE1).strip.should eq DATA1
        File.read(CRYPTREPO+"/"+FILE2).strip.should eq DATA2
    end
    
    it "cloning crypted repo" do
        %x(
            pushd #{TMPDIR}
            git clone #{CRYPTREPO} #{CRYPTREPO2}
        )
        File.read(CRYPTREPO2+"/"+FILE1).strip.should_not eq DATA1
        File.read(CRYPTREPO2+"/"+FILE2).strip.should eq DATA2

        %x(
            pushd #{CRYPTREPO2}
            echo "\nn\npasswd\n\n\n\n#{FILE1}\n" | gitcrypt init
            git reset --hard
        )
        File.read(CRYPTREPO2+"/"+FILE1).strip.should eq DATA1
        File.read(CRYPTREPO2+"/"+FILE2).strip.should eq DATA2
    end

    it "recrypting repo" do
        newpass = "newpass"
        %x(
            pushd #{CRYPTREPO2}
            echo "\n#{newpass}\n" |gitcrypt recrypt
        )
        %x(cd #{CRYPTREPO2} && git config gitcrypt.pass).strip.should eq newpass
        File.read(CRYPTREPO2+"/"+FILE1).strip.should eq DATA1
        File.read(CRYPTREPO2+"/"+FILE2).strip.should eq DATA2
    end

    it "decrypting repo" do
        %x(
            pushd #{CRYPTREPO2}
            gitcrypt decrypthistory
            pushd #{TMPDIR}
            git clone #{CRYPTREPO2} #{DECRYPTREPO}
        )
        File.read(DECRYPTREPO+"/"+FILE1).strip.should eq DATA1
        File.read(DECRYPTREPO+"/"+FILE2).strip.should eq DATA2
    end

end

