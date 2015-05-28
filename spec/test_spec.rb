#!/usr/bin/env ruby
require 'rspec'

RSpec.configure do |config|
  config.color = true
  config.tty = true
  config.formatter = :documentation
end

TMPDIR=%x(mktemp -d).strip
BASEREPO="#{TMPDIR}/base"
# CRYPTREPO="#{TMPDIR}/crypt"
# CRYPTREPO2="#{TMPDIR}/crypt2"
# CRYPTREPO3="#{TMPDIR}/crypt3"
# DECRYPTREPO="#{TMPDIR}/decrypt"

FILE1="file1"
DATA1="123\n321\n555\nabcdef\we must make some diff context\nqweqwe\nasdasd\nzxczxc\nrtyfghvbn\nhjkhjk"

FILE2="file2"
DATA2="asd\nefg\nzxc\nqwerty"

def clone_repo base, path
  Dir.chdir TMPDIR

  path = %x(
    git clone #{base} #{path}
    cd #{path}
    pwd
  ).split("\n").last.strip

  yield path if block_given?
  return path
end


NAMES={cr: 'crypted', cr1: 'crypted_1', re: 'recrypted', cr2: 'crypted_2', dc1: 'decrypted'}

describe "Preparing git repo" do

    before(:all) do
      @repos = {}
    end

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
        expect(File.read(BASEREPO+"/"+FILE1).strip).to eq DATA1
        expect(File.read(BASEREPO+"/"+FILE2).strip).to eq DATA2
    end

    it "creating crypted repo [#{NAMES[:cr]}]" do
        @repos[:cr] = clone_repo BASEREPO, NAMES[:cr] do |repo|
          Dir.chdir repo
          expect(File.read(FILE1).strip).to eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2

          %x(
              echo "\nn\npasswd\n\n\n\n#{FILE1}\n" | gitcrypt init
              git reset --hard
          )

          #fail on unencrypted file
          expect(File.read(FILE1).strip).to eq ""
          expect(File.read(FILE2).strip).to eq DATA2
        end
    end

    it "crypting repo [#{NAMES[:cr]}] history" do
        Dir.chdir @repos[:cr]
        %x(
            echo "y\n" | gitcrypt crypthistory
        )
        expect(File.read(FILE1).strip).to eq DATA1
        expect(File.read(FILE2).strip).to eq DATA2
    end
    
    it "cloning crypted repo [#{NAMES[:cr]}] to [#{NAMES[:cr1]}]" do

        @repos[:cr1] = clone_repo @repos[:cr], NAMES[:cr1] do |repo|
          Dir.chdir repo
          expect(File.read(FILE1).strip).to_not eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2

          %x(
              echo "\nn\npasswd\n\n\n\n#{FILE1}\n" | gitcrypt init
              git reset --hard
          )

          expect(File.read(FILE1).strip).to eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2
        end
    end

    it "recrypting repo [#{NAMES[:cr1]}]" do
        Dir.chdir @repos[:cr1]
        newpass = "newpass"
        %x(
            echo "\n#{newpass}\n" | gitcrypt recrypt
        )

        @repos[:re] = clone_repo @repos[:cr1], NAMES[:re] do |repo|
          Dir.chdir repo
          expect(File.read(FILE1).strip).to_not eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2

          %x(
              echo "\nn\n#{newpass}\n\n\n\n#{FILE1}\n" | gitcrypt init
              git reset --hard
          )

          expect(%x(git config gitcrypt.pass).strip).to eq newpass
          expect(File.read(FILE1).strip).to eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2
        end

    end

    it "decrypting repo [#{NAMES[:cr1]}]" do
        Dir.chdir @repos[:cr1]
        %x(
            gitcrypt decrypthistory
        )

        @repos[:dc1] = clone_repo @repos[:cr1], NAMES[:dc1] do |repo|
          Dir.chdir repo
          expect(File.read(FILE1).strip).to eq DATA1
          expect(File.read(FILE2).strip).to eq DATA2
        end
        

    end

    it "merging crypted repos [#{NAMES[:cr]}] and [#{NAMES[:cr2]}]" do
  		NEWDATA1_PREF = "NEWDATA\n#{DATA1}"
  		NEWDATA1_SUFF = "#{DATA1}\nNEWDATA"

      @repos[:cr2] = clone_repo @repos[:cr], NAMES[:cr2] do |repo|
        Dir.chdir repo
        %x(
            echo "\nn\npasswd\n\n\n\n#{FILE1}\n" | gitcrypt init
            git reset --hard
        ) 
        expect(File.read(FILE1).strip).to eq DATA1
        expect(File.read(FILE2).strip).to eq DATA2
      end

      Dir.chdir @repos[:cr]
      %x(
        echo -e "#{NEWDATA1_PREF}" > #{FILE1}
        git add "#{FILE1}"
        git commit -am "commit for merge 1"
      )

      Dir.chdir @repos[:cr2]
      %x(
        echo -e "#{NEWDATA1_SUFF}" > #{FILE1}
        git add "#{FILE1}"
        git commit -am "commit for merge 2"
      )

      expect(File.read(@repos[:cr]+"/"+FILE1).strip).to eq NEWDATA1_PREF
      expect(File.read(@repos[:cr]+"/"+FILE2).strip).to eq DATA2

      expect(File.read(@repos[:cr2]+"/"+FILE1).strip).to eq NEWDATA1_SUFF
      expect(File.read(@repos[:cr2]+"/"+FILE2).strip).to eq DATA2

      Dir.chdir @repos[:cr2]

      %x(
        git pull
      )

      expect(File.read(FILE1).strip).to eq "NEWDATA\n#{DATA1}\nNEWDATA"

    end


    it "merging CONFLICTED crypted repos [#{NAMES[:cr]}] and [#{NAMES[:cr2]}]" do
      NEWDATA1_PREF = "CONFLICTED\n#{DATA1}"
      NEWDATA1_SUFF = "ANOTHER_CONFLICTED#{DATA1}"

      Dir.chdir @repos[:cr]
      %x(
        echo -e "#{NEWDATA1_PREF}" > #{FILE1}
        git add "#{FILE1}"
        git commit -am "commit for conflict 1"
      )

      Dir.chdir @repos[:cr2]
      %x(
        echo -e "#{NEWDATA1_SUFF}" > #{FILE1}
        git add "#{FILE1}"
        git commit -am "commit for conflict 2"
      )

      expect(File.read(@repos[:cr]+"/"+FILE1).strip).to eq NEWDATA1_PREF
      expect(File.read(@repos[:cr]+"/"+FILE2).strip).to eq DATA2

      expect(File.read(@repos[:cr2]+"/"+FILE1).strip).to eq NEWDATA1_SUFF
      expect(File.read(@repos[:cr2]+"/"+FILE2).strip).to eq DATA2

      Dir.chdir @repos[:cr2]

      %x(
        git pull
      )

      conflict = %x(
        git status | grep "both modified"
        echo $?
      ).split("\n").last.strip == "0"

      expect(conflict).to eq true

      %x(
        git checkout --theirs file1
        git add file1
        git commit -m "take other changes"
      )

      expect(File.read(@repos[:cr2]+"/"+FILE1).strip).to eq File.read(@repos[:cr]+"/"+FILE1).strip
    end

end

