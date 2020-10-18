require 'erubi'
require 'json'

def ask(question, options = {})
  if options.empty?
    print question, ' '
    gets.strip
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

def mkdir_p(dir)
  return if dir.gsub('.', '').gsub(File::SEPARATOR, '').empty?
  path = dir.split(File::SEPARATOR)
  if path.size == 1
    Dir.mkdir(dir) unless Dir.exist?(dir)
    return
  end
  path.reduce do |a, e|
    current = a + File::SEPARATOR + e
    Dir.mkdir(current) unless Dir.exist?(current)
    current
  end
end

def erb(save_to, read_from, **locals)
  b = binding
  locals.each { |k, v| b.local_variable_set(k, v) }

  file_name = File.join(__dir__, 'configs', read_from)

  result = b.eval(Erubi::Engine.new(File.read(file_name)).src)

  mkdir_p(File.dirname(save_to))
  File.write(save_to, result, mode: 'w')
end

answers = {}

answers[:git_hooks] = yes?('Add git hooks?')
answers[:branch] = ask('Main git branch? Press Enter to use branch "master".')
answers[:branch] = 'master' if answers[:branch].empty?

answers[:package] = ask('Package manager', {
  npm:  'NPM',
  yarn: 'Yarn',
})

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

answers[:ts] = yes?('Using TypeScript?')
answers[:vue] = yes?('Using Vue?')
answers[:svelte] = yes?('Using Svelte?')
if answers[:eslint] && answers[:vue]
  answers[:import] = yes?(
    'Add ESLint plugin for sorting imports in components?'
  )
end

answers[:stylelint] = yes?('Add StyleLint?')

answers[:ts_svelte] = answers[:ts] && answers[:svelte]
answers[:ts_eslint] = answers[:ts] && answers[:eslint]
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
  ts:            'typescript tslib',
  ts_eslint:     '@typescript-eslint/eslint-plugin @typescript-eslint/parser',
  ts_svelte:     '@tsconfig/svelte',
}.select { |k, _| answers[k] }.values.join(' ')

if answers[:package] == 'yarn'
  `yarn add #{dev_packages} --dev` unless dev_packages.empty?
else
  `npm install #{dev_packages} -D` unless dev_packages.empty?
end

if answers[:git_hooks]
  json = JSON.parse(File.read('package.json'))
  json['gitHooks'] = {
    "post-commit": "ruby hooks/post-commit.rb",
    "pre-push": "ruby hooks/pre-push.rb"
  }
  File.write('package.json', JSON.pretty_generate(json))

  erb(
    'hooks/post-commit.rb', 'git-hook.erb',
    hook: :post_commit, answers: answers
  )
  erb(
    'hooks/pre-push.rb', 'git-hook.erb',
    hook: :pre_push, answers: answers
  )
end

if answers[:eclint]
  erb('.editorconfig', 'editor_config.erb', answers: answers)
end

if answers[:eslint]
  erb('.eslintrc.yml', 'eslint_rc.erb', answers: answers)
end

if answers[:stylelint]
  erb('.stylelintrc.yml', 'stylelint_rc.erb')
end

puts 'Done'
