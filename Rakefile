
PROJECT_NAME = 'jruby-rack-worker'
PROJECT_VERSION = '0.1'

SRC_DIR = 'src'
JAVA_SRC_DIR = File.join(SRC_DIR, 'main/java')
OUT_DIR = 'out'
JAVA_BUILD_DIR = File.join(OUT_DIR, 'classes')
LIB_DIR = 'lib'

require 'ant'
ant.property :name => "ivy.lib.dir", :value => LIB_DIR

namespace :ivy do

  ivy_version = '2.1.0'
  ivy_jar_dir = File.join(LIB_DIR, 'build')
  ivy_jar_file = File.join(ivy_jar_dir, 'ivy.jar')

  task :download do
    mkdir_p ivy_jar_dir
    ant.get :src => "http://repo1.maven.org/maven2/org/apache/ivy/ivy/#{ivy_version}/ivy-#{ivy_version}.jar",
      :dest => ivy_jar_file,
      :usetimestamp => true
  end

  task :install => :download do
    ant.path :id => 'ivy.lib.path' do
      fileset :dir => ivy_jar_dir, :includes => '*.jar'
    end
    ant.taskdef :resource => "org/apache/ivy/ant/antlib.xml", :classpathref => "ivy.lib.path"
  end
  
end

task :retrieve => :"ivy:install" do
  ant.retrieve :pattern => "${ivy.lib.dir}/[conf]/[artifact].[type]"
end

ant.path :id => "build.class.path" do
  fileset :dir => LIB_DIR do
    include :name => 'runtime/*.jar'
  end
end

task :compile => :retrieve do
  mkdir_p JAVA_BUILD_DIR
  ant.javac :destdir => JAVA_BUILD_DIR, :source => '1.5' do
    src :path => JAVA_SRC_DIR
    classpath :refid => "build.class.path"
  end
end

task :jar => :compile do
  ant.jar :destfile => "#{OUT_DIR}/#{PROJECT_NAME}_#{PROJECT_VERSION}.jar", :basedir => JAVA_BUILD_DIR do
    manifest do
      attribute :name => "Built-By", :value => "${user.name}"
      attribute :name => "Implementation-Title", :value => PROJECT_NAME
      attribute :name => "Implementation-Version", :value => PROJECT_VERSION
      attribute :name => "Implementation-Vendor", :value => "Karol Bucek"
      attribute :name => "Implementation-Vendor-Id", :value => "org.kares"
    end
  end
end

task :clean do
  rm_rf OUT_DIR
end

task :default => [ :jar ]
