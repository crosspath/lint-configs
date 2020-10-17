def ask(question, options = {})
  if options.empty?
    print question, ' '
    gets.chomp
  else
    options.transform_keys!(&:to_s)
    align = options.keys.max { |k1, k2| k1.size <=> k2.size }.size
    loop do
      puts '=' * 12, question, '-' * 12
      options.each do |k, v|
        puts "#{k.rjust(align)}: #{v}"
      end
      print '? '
      result = gets.strip
      return result if options.keys.include?(result)
    end
  end
end

def yes?(question)
  loop do
    print "#{question} (y/n) "
    case gets.strip
    when 'y'
      return true
    when 'n'
      return false
    end
  end
end

def erb(save_to, read_from, **locals)
  b = binding
  locals.each { |k, v| b.local_variable_set(k, v) }

  file_name = File.join(__dir__, 'configs', read_from)

  result = b.eval(Erubi::Engine.new(File.read(file_name)).src)

  File.write(save_to, result)
end

answers = {}

answers[:git_hooks] = yes?('Add git hooks?')
answers[:eclint] = yes?('Add ECLint?')
if answers[:eclint]
  answers[:eclint_preset] = ask('Preset for ECLint', {
    js:   'JavaScript project',
    ruby: 'Ruby on Rails project',
  })
end
answers[:eslint] = yes?('Add ESLint?')
if answers[:eslint]
  answers[:filenames] = ask('Add ESLint plugin for filenames?', {
    pc: 'Yes, use PascalCase',
    cc: 'Yes, use camelCase',
    sc: 'Yes, use snake_case',
    kc: 'Yes, use kebab-case',
    no: 'No'
  })
  answers[:filenames] = false if answers[:filenames] == 'no'
end
answers[:vue] = yes?('Using Vue?')
answers[:svelte] = yes?('Using Svelte?')
if answers[:eslint] && (answers[:vue] || answers[:svelte])
  answers[:import] = yes?(
    'Add ESLint plugin for sorting imports in components?'
  )
end
answers[:stylelint] = yes?('Add StyleLint?')

answers[:vue_eslint] = answers[:vue] && answers[:eslint]
answers[:svelte_eslint] = answers[:svelte] && answers[:eslint]

dev_packages = {
  git_hooks:     'yorkie',
  eclint:        'eclint',
  eslint:        'eslint eslint-plugin-eslint-comments',
  filenames:     'eslint-plugin-filename-rules',
  import:        'eslint-plugin-simple-import-sort',
  vue_eslint:    'eslint-plugin-vue',
  svelte_eslint: 'eslint-plugin-svelte3',
  stylelint:     'stylelint',
}.select { |k, _| answers[k] }.values.join(' ')

`yarn add #{dev_packages} --dev` unless dev_packages.empty?

if answers[:git_hooks]
  `yarn config set gitHooks --json '{\
    "post-commit": "ruby hooks/post-commit.rb",\
    "pre-push": "ruby hooks/pre-push.rb"\
  }'`

  erb(
    'git-hook.erb', 'hooks/post-commit.rb',
    hook: :post_commit, answers: answers
  )
  erb(
    'git-hook.erb', 'hooks/pre-push.rb',
    hook: :pre_push, answers: answers
  )
end

if answers[:eclint]
  erb('editor_config.erb', '.editorconfig', answers: answers)
end

if answers[:eslint]
  erb('eslint_rc.erb', '.eslintrc.yml', answers: answers)
end

if answers[:stylelint]
  erb('stylelint_rc.erb', '.stylelintrc.yml')
end

puts 'Done'
