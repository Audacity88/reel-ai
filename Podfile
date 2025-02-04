platform :ios, '14.0'
use_frameworks!

target 'Reel-AI' do
  pod 'FirebaseAnalytics'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'FirebaseMessaging'
  pod 'FirebaseFunctions'
  
  # Add this post_install for M1 Mac compatibility
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        # Ensure frameworks can be found
        config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
        # Add arm64 to excluded architectures for simulators on Apple Silicon
        if config.build_settings['SDKROOT'] == 'iphoneos' && config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 14.0
          config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
        end
      end
    end
  end
end 