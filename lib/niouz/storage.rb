module Niouz
  # This class manages the "database" of groups and articles.
  class Storage
    def initialize(dir)
      File.open(File.join(dir, 'newsgroups')) do |file|
        @groups = load_groups(file)
      end
      @pool = File.join(dir, 'articles')
      @last_file_id = 0
      @lock = Mutex.new
      @articles = Hash.new
      Dir.foreach(@pool) do |fname|
        next if fname[0] == ?.
        @last_file_id = [ @last_file_id, fname.to_i ].max
        register_article(fname)
      end
    end

    # Parses the newsgroups description file.
    def load_groups(input)
      groups = Hash.new
      while g = Niouz.parse_rfc822_header(input)
        date = Niouz.parse_date(g['Date-Created'])
        groups[g['Name']] = Newsgroup.new(g['Name'], date, g['Description'])
      end
      return groups
    end

    def register_article(fname)
      art = Article.new(File.join(@pool, fname))
      @articles[art.mid] = art
      art.newsgroups.each do |gname|
        @groups[gname].add(art) if has_group?(gname)
      end
    end

    private :register_article, :load_groups

    def group(name)
      return @groups[name]
    end

    def has_group?(name)
      return @groups.has_key?(name)
    end

    def each_group
      @groups.each_value {|grp| yield(grp) }
    end

    def article(mid)
      return @lock.synchronize { @articles[mid] }
    end

    def groups_of(article)
      return article.newsgroups.collect { |name| @groups[name] }
    end

    def each_article
      articles = @lock.synchronize { @articles.dup }
      articles.each { |key, art| yield(art) }
    end

    def create_article(content)
      begin
        @lock.synchronize {
          @last_file_id += 1;
          fname = "%06d" % [ @last_file_id ]
          File.open(File.join(@pool, fname), "w") { |f| f.write(content) }
          register_article(fname)
        }
        return true
      rescue
        return false
      end
    end

    def gen_uid
      return "<" + MD5.hexdigest(Time.now.to_s) + "@" + Socket.gethostname + ">"
    end
  end
end
