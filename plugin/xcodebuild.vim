" Modified: hujie.code@gmail.com
" Description:	An easy way to use xcodebuild with Vim
" Author: Jerry Marino <@jerrymarino>
" License: Vim license
" Version .45

let s:projects = []
let s:project = '' 
let s:targets = []
let s:target = ''
let s:buildConfigs = []
let s:buildConfig = ''
let s:schemes = []
let s:scheme = ''
let s:sdks = []
let s:sdk = ''
let s:noProjectError = 'Missing .xcodeproj'
let s:xcodeproj_info_file = '.xcodeproj_info'

fun g:XCB_Init()
    call g:XCB_GenerateBuildInfoIfNeeded()

    if s:projectIsValid()	
        set errorformat=
                    \%f:%l:%c:{%*[^}]}:\ error:\ %m,
                    \%f:%l:%c:{%*[^}]}:\ fatal\ error:\ %m,
                    \%f:%l:%c:{%*[^}]}:\ warning:\ %m,
                    \%f:%l:%c:\ error:\ %m,
                    \%f:%l:%c:\ fatal\ error:\ %m,
                    \%f:%l:%c:\ warning:\ %m,
                    \%f:%l:\ Error:\ %m,
                    \%f:%l:\ error:\ %m,
                    \%f:%l:\ fatal\ error:\ %m,
                    \%f:%l:\ warning:\ %m

        call g:XCB_UpdateXCConfig()
        call s:setKeysAndAutocmds()
    endif
endf

fun s:projectIsValid()
    if !empty(s:project)
        return 1
    endif
    return 0
endf

fun s:setKeysAndAutocmds() 
    " Build current target
    nn <leader>xx :call g:XCB_Build()<cr> 
    " Clean current target
    nn <leader>xk :call g:XCB_Clean()<cr> 
    " Show build command 
    nn <leader>xi :call g:XCB_BuildCommandInfo()<cr> 
    " Generate compile_commands
    nn <leader>xc :call g:XCB_GenerateCompileCommandsIfNeeded()<cr>:CocRestart<cr>
    " Open xcode with current project
    nn <space>x :wa<cr>:call g:XCB_OpenXCode()<cr>

    autocmd BufWritePost .xcodeproj_info call g:XCB_UpdateXCConfig()
endf

fun g:XCB_GenerateBuildInfoIfNeeded()
    let s:project = s:findProjectFileName()
    let has_info_file = filereadable(getcwd()."/".s:xcodeproj_info_file)
    " No xcoderoject found and no project setting.
    if empty(s:project) && !has_info_file
        return 
    endif

    " Found xcodeproj in current dir, add xcode build info file.
    if !has_info_file
        call system("touch ".s:xcodeproj_info_file)
    endif

    call g:XCB_UpdateXCConfig()

    " No target found need generate.
    if !len(s:target)
        echom s:project
        let outputList = split(system("xcodebuild -list -project ".s:project), '\n')
        let configTypeEx = '\([^ :0-9"]\([a-zA-Z ]*\)\(:\)\)'
        let typeSettingEx = '\([^ ]\w\w\+$\)'

        let configVarToTitleDict = {'Build Configurations:' : s:buildConfigs, 'Targets:' : s:targets, 'Schemes:' : s:schemes}
        let configVar = []
        for line in outputList 
            if match(line, configTypeEx) > 1
                let typeTitle = matchstr(line, configTypeEx)
                if has_key(configVarToTitleDict, typeTitle)  	
                    let configVar = get(configVarToTitleDict, typeTitle, 'default') 
                endif
            elseif match(line, typeSettingEx) > 1 
                let typeSetting = matchstr(line, typeSettingEx)
                if strlen(typeSetting) > 1
                    call add(configVar, typeSetting)
                endif
            endif
        endfor

        " Default select first one, write configuration to file.
        let s:buildConfigs[0] = '* '.s:buildConfigs[0]
        let s:targets[0] = '* '.s:targets[0]
        let s:schemes[0] = '* '.s:schemes[0]

        let write_items = ['', 'SDKs:', 'iphoneos -arch arm64', 'iphonesimulator', 'macosx']
        call extend(write_items, ['', 'Build Configurations:'])
        call extend(write_items, s:buildConfigs)

        call extend(write_items, ['', 'Targets:'])
        call extend(write_items, s:targets)

        call extend(write_items, ['', 'Schemes:'])
        call extend(write_items, s:schemes)

        call writefile(write_items, s:xcodeproj_info_file, "a")
    endif
endf

fun g:XCB_UpdateXCConfig()
    let outputList = split(system("cat ".s:xcodeproj_info_file), '\n')

    let configTypeEx = '[a-zA-Z ]*:'
    let typeSettingEx = '^* .*'

    let configVarToTitleDict = {'Projects:' : s:projects, 'SDKs:' : s:sdks, 'Build Configurations:' : s:buildConfigs, 'Targets:' : s:targets, 'Schemes:' : s:schemes}
    for line in outputList 
        if match(line, configTypeEx) == 0
            let typeTitle = matchstr(line, configTypeEx)
        elseif match(line, typeSettingEx) == 0 
            let typeSetting = matchstr(line, typeSettingEx)
            if strlen(typeSetting) > 1
                if typeTitle == 'Projects:'
                    let s:project = typeSetting[2:]
                elseif typeTitle == 'SDKs:'
                    let s:sdk = typeSetting[2:]
                elseif typeTitle == 'Build Configurations:'
                    let s:buildConfig  = typeSetting[2:]
                elseif typeTitle == 'Targets:'
                    let s:target = typeSetting[2:]
                elseif typeTitle == 'Schemes:'
                    let s:scheme = typeSetting[2:]
                endif
            endif
        endif
    endfor
endf

fun s:XcodeCommandWithTarget(target)
    let cmd = "xcodebuild"
    if(!empty(s:sdk))
        let cmd .= " -sdk " . s:sdk
    endif
    if(!empty(s:buildConfig))
        let cmd .= " -configuration " . s:buildConfig
    endif
    if(!empty(s:scheme))
        let cmd .= " -scheme " . s:scheme
    endif
    if (!empty(s:project))
        let cmd .= " -project " . s:project
    endif
    return cmd
endf

fun g:XCB_Build()
    if !s:projectIsValid()	
        echoerr s:noProjectError
        return
    endif
    call s:asyncRunBuildCommand(s:XcodeCommandWithTarget(s:target) . ' build')
endf

fun g:XCB_Clean()
    if !s:projectIsValid()	
        echoerr s:noProjectError
        return
    endif
    call s:asyncRunBuildCommand(s:XcodeCommandWithTarget(s:target) . ' clean')
endf

fun g:XCB_BuildCommandInfo()
    if !s:projectIsValid()	
        echoerr s:noProjectError
        return
    endif
    echo s:XcodeCommandWithTarget(s:target) . ' build'
endf	

fun s:findProjectFileName()
    let s:projectFile = globpath(expand('.'), '*.xcodeproj')
    return s:projectFile
endf

fun g:XCB_GenerateCompileCommandsIfNeeded()
    if !s:projectIsValid()	
        return
    endif
    if !filereadable(getcwd()."/compile_commands.json")
        " Clean first
        exec "!" . s:XcodeCommandWithTarget(s:target) . ' clean'
        let build_cmd = s:XcodeCommandWithTarget(s:target) . ' build | xcpretty -r json-compilation-database --output compile_commands.json'
        call system(build_cmd)
        call system('gsed -e "s/[^ ]*[gf]modules[^ ]*//g" -e "s/-index-store-path [^ ]*//g" -i compile_commands.json')
    end
endf

fun s:asyncRunBuildCommand(cmd)
    exec "AsyncRun " . a:cmd 
endf

fun g:XCB_OpenXCode()
    call system("open ". s:project)
endf

call g:XCB_Init()
