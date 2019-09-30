class Tengine < Formula
  homepage "http://tengine.taobao.org"
  url "https://tengine.taobao.org/download/tengine-2.3.3.tar.gz"
  sha256 "adf19c9c9ae6bb1efb681e28f6d4ce50dd6a163ecfd33ddf2c05c4c1add9ff45"
  head "https://github.com/alibaba/tengine.git"

  def self.core_modules
    [
      ["jemalloc",         nil,                        "Optimization of jemalloc memory management"],
      ["passenger",        nil,                        "Compile with support for Phusion Passenger module"],
      ["webdav",           "http_dav_module",          "Compile with support for WebDAV module"],
      ["http2",            "http_v2_module",           "Compile with support for HTTP2 module"],
      ["gunzip",           "http_gunzip_module",       "Compile with support for gunzip module"],
      ["secure-link",      "http_secure_link_module",  "Compile with support for secure link module"],
      ["mp4",              "http_mp4_module",          "Compile with support for mp4 module"],
      ["realip",           "http_realip_module",       "Compile with support for real IP module"],
      ["perl",             "http_perl_module",         "Compile with support for Perl module"],
      ["sub",              "http_sub_module",          "Compile with support for HTTP Sub module"],
      ["addition",         "http_addition_module",     "Compile with support for HTTP Addition module"],
      ["degredation",      "http_degradation_module",  "Compile with support for HTTP Degredation module"],
      ["flv",              "http_flv_module",          "Compile with support for FLV module"],
      ["geoip",            "http_geoip_module",        "Compile with support for GeoIP module"],
      ["gzip-static",      "http_gzip_static_module",  "Compile with support for Gzip static module"],
      ["image-filter",     "http_image_filter_module", "Compile with support for Image Filter module"],
      ["random-index",     "http_random_index_module", "Compile with support for Random Index module"],
      ["xslt",             "http_xslt_module",         "Compile with support for XSLT module"],
    #  ["auth-req",         "http_auth_request_module", "Compile with support for HTTP Auth Request Module"],
      ["mail",             "mail",                     "Compile with support for Mail module"],
      ["debug",            "debug",                    "Compile with support for debug log"],
      ["pcre-jit",         "pcre-jit",                 "Compile with support for JIT in PCRE"],
      ["google-perftools", "google_perftools_module",  "Compile with support for Google Performance tools module"]
    ]
  end

  depends_on "geoip" => :optional
  depends_on "jemalloc" => :optional
  depends_on "libxml2" if build.with? "xslt"
  depends_on "libxslt" if build.with? "xslt"
  depends_on "luajit" => :optional
  depends_on "openssl"
  depends_on "passenger" => :optional
  depends_on "pcre"
  depends_on "gd" if build.with? "image-filter"

  conflicts_with 'nginx', 'denji/nginx/nginx-full',
    :because => "nginx, denji/nginx/nginx-full install the same binaries."

  self.core_modules.each do |arr|
    option "with-#{arr[0]}", arr[2]
  end

  env :userpaths
  skip_clean "logs"

  def passenger_config_args
    passenger_config = "#{HOMEBREW_PREFIX}/opt/passenger/bin/passenger-config"
    tengine_ext = `#{passenger_config} --nginx-addon-dir`.chomp

    if File.directory?(tengine_ext)
      return "--add-module=#{tengine_ext}"
    end

    puts "Unable to install tengine with passenger support."
    exit
  end

  def install
    # Changes default port to 8080
    inreplace "conf/nginx.conf", "listen       80;", "listen       8080;"

    pcre = Formula["pcre"]
    openssl = Formula["openssl"]
    cc_opt = "-I#{HOMEBREW_PREFIX}/include -I#{pcre.include} -I#{openssl.include}"
    ld_opt = "-L#{HOMEBREW_PREFIX}/lib -L#{pcre.lib} -L#{openssl.lib}"

    args = ["--prefix=#{prefix}",
            "--with-http_ssl_module",
            "--with-pcre",
            "--sbin-path=#{bin}/nginx",
            "--with-cc-opt=#{cc_opt}",
            "--with-ld-opt=#{ld_opt}",
            "--conf-path=#{etc}/tengine/nginx.conf",
            "--pid-path=#{var}/run/tengine.pid",
            "--lock-path=#{var}/run/tengine.lock",
            "--http-client-body-temp-path=#{var}/run/tengine/client_body_temp",
            "--http-proxy-temp-path=#{var}/run/tengine/proxy_temp",
            "--http-fastcgi-temp-path=#{var}/run/tengine/fastcgi_temp",
            "--http-uwsgi-temp-path=#{var}/run/tengine/uwsgi_temp",
            "--http-scgi-temp-path=#{var}/run/tengine/scgi_temp",
            "--http-log-path=#{var}/log/tengine/access.log",
            "--error-log-path=#{var}/log/tengine/error.log"
          ]

    # Core Modules
    args += self.class.core_modules.select { |arr|
      build.with? arr[0]
    }.collect { |arr|
      "--with-#{arr[1]}" if arr[1]
    }.compact

    # Passenger
    args << passenger_config_args if build.with? "passenger"

    # Install Lua or LuaJit
    if build.with? "luajit"
      luajit_path = `brew --prefix luajit`.chomp
      args << "--with-http_lua_module"
      args << "--with-luajit-inc=#{luajit_path}/include/luajit-2.0"
      args << "--with-luajit-lib=#{luajit_path}/lib"
    end

    if build.with? "jemalloc"
      jemalloc = Formula["jemalloc"]
      cc_opt += " -I#{jemalloc.opt_prefix}/include"
      ld_opt += " -L#{jemalloc.opt_prefix}/lib"
      args << "--with-jemalloc"
    end

    if build.head?
      system "./auto/configure", *args
    else
      system "./configure", *args
    end
    system "make"
    system "make install"
    man8.install "objs/nginx.8"
    (var/"run/tengine").mkpath
  end

  def post_install
    # tengine"s docroot is #{prefix}/html, this isn"t useful, so we symlink it
    # to #{HOMEBREW_PREFIX}/var/www. The reason we symlink instead of patching
    # is so the user can redirect it easily to something else if they choose.
    html = prefix/"html"
    dst  = var/"www"

    if dst.exist?
      html.rmtree
      dst.mkpath
    else
      dst.dirname.mkpath
      html.rename(dst)
    end

    prefix.install_symlink dst => "html"

    # for most of this formula's life the binary has been placed in sbin
    # and Homebrew used to suggest the user copy the plist for tengine to their
    # ~/Library/LaunchAgents directory. So we need to have a symlink there
    # for such cases
    if rack.subdirs.any? { |d| d.join("sbin").directory? }
      sbin.install_symlink bin/"nginx"
    end
  end

  test do
    system "#{bin}/nginx", "-t"
  end

  def passenger_caveats; <<~EOS

    To activate Phusion Passenger, add this to #{etc}/tengine/nginx.conf, inside the 'http' context:
      passenger_root #{HOMEBREW_PREFIX}/opt/passenger/libexec/lib/phusion_passenger/locations.ini;
      passenger_ruby /usr/bin/ruby;
    EOS
  end

  def caveats
    s = <<~EOS
    Docroot is: #{HOMEBREW_PREFIX}/var/www

    The default port has been set in #{HOMEBREW_PREFIX}/etc/tengine/nginx.conf to 8080 so that
    tengine can run without sudo.

    - Tips -
    Run port 80:
     $ sudo chown root:wheel #{sbin}/nginx
     $ sudo chmod u+s #{sbin}/nginx
    Reload config:
     $ nginx -s reload
    Reopen Logfile:
     $ nginx -s reopen
    Stop process:
     $ nginx -s stop
    Waiting on exit process
     $ nginx -s quit
    EOS
    s << passenger_caveats if build.with? "passenger"
    s
  end

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_bin}/nginx</string>
            <string>-g</string>
            <string>daemon off;</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
      </dict>
    </plist>
    EOS
  end
end
