platform :ios, '12.0'  # Set minimum iOS version to 12.0

target 'DictationEasy' do
  use_frameworks!

  # Pods for DictationEasy
  pod 'Google-Mobile-Ads-SDK'
 
end

post_install do |installer|
  # Patch the Pods-DictationEasy-resources.sh script to remove the --m or -mq options from realpath
  resources_script = "Pods/Target Support Files/Pods-DictationEasy/Pods-DictationEasy-resources.sh"
  if File.exist?(resources_script)
    text = File.read(resources_script)
    # Remove both 'realpath -mq' and 'realpath --m'
    new_text = text.gsub(/realpath -mq/, "realpath -q").gsub(/realpath --m/, "realpath")
    File.write(resources_script, new_text)
    puts "Patched #{resources_script} to remove 'realpath -mq' and 'realpath --m'"
  else
    puts "Warning: #{resources_script} not found during post_install"
  end
end
