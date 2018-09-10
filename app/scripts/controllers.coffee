window.c = console ? log : _.noop
littb = angular.module('littbApp')

window.detectIE = () ->
    ua = window.navigator.userAgent

    msie = ua.indexOf('MSIE ')
    if (msie > 0)
        # IE 10 or older => return version number
        return parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)), 10)
    

    trident = ua.indexOf('Trident/')
    if (trident > 0)
        # IE 11 => return version number
        rv = ua.indexOf('rv:')
        return parseInt(ua.substring(rv + 3, ua.indexOf('.', rv)), 10)
    

    edge = ua.indexOf('Edge/')
    if (edge > 0)
       # Edge (IE 12+) => return version number
       return parseInt(ua.substring(edge + 5, ua.indexOf('.', edge)), 10)
    

    # other browser
    return false



littb.filter "formatAuthors", (authors) ->
    (authorlist, authorsById, makeLink, noHTML) ->
        if not authorlist or not authorlist.length or not authorsById then return

        stringify = (auth) ->
            suffix = {
                editor : " <span class='authortype'>red.</span>"
                translator : " <span class='authortype'>övers.</span>"
                illustrator : " <span class='authortype'>ill.</span>"
                photographer : " <span class='authortype'>fotogr.</span>"
                # scholar : " (red.)"


            }[auth.type] or ""
            if noHTML then suffix = $(suffix).text()
            authorsById[auth.author_id].full_name + suffix
        
        linkify = (auth) ->
            $("<a>").attr "href", "/forfattare/#{auth.author_id}"
                .html stringify auth
                .outerHTML()

        if makeLink
            strings = _.map authorlist, linkify
        else
            strings = _.map authorlist, stringify
        

        firsts = strings[...-1]
        last = _.last strings


        if noHTML
            et = "&"
        else
            et = "<em class='font-normal'>&</em>"
        if firsts.length then return "#{firsts.join(', ')} #{et} #{last}"
        else return last
        


littb.filter "downloadMediatypes", () ->
    (obj) ->
        (x for x in (obj?.mediatypes or []) when x.downloadable)

littb.filter "readMediatypes", () ->
    read = ['etext', 'faksimil']
    (obj) ->
        (x for x in (obj?.mediatypes or []) when x.label in read)


        

c.time = angular.noop
c.timeEnd = angular.noop

littb.filter "authorYear", () ->
    (obj) ->
        unless obj then return
        isFalsy = (val) ->
            not val or (val == "0000")
        birth = obj.birth?.plain
        death = obj.death?.plain
        if (isFalsy birth) and (isFalsy death) then return ""
        if isFalsy death then return "f. #{birth}"
        if isFalsy birth then return "d. #{death}"
        return "#{birth}-#{death}"


littb.controller "startCtrl", ($scope, $location) ->

    $scope.gotoTitle = (query) ->
        unless query
            url = "/titlar"
        else
            url = "/titlar?filter=#{query}&selectedLetter=#{query[0].toUpperCase()}"

        $scope.goto url



littb.controller "contactFormCtrl", ($scope, backend, $timeout, $location) ->
    s = $scope

    fromSchool = $location.search().skola?
    isSOL = $location.search().sol?

    if isSOL
        s.message = "[Ang. Översättarlexikon]\n\n"

    s.showContact = false
    s.showNewsletter = false
    s.showError = false

    done = () ->
        $timeout( () ->
            s.showContact = false
            s.showNewsletter = false
        , 4000)

    err = () ->
        s.showError = true
        s.showContact = false
        s.showNewsletter = false

        $timeout( () ->
            s.showError = false
        , 4000)

    s.submitContactForm = () ->
        if fromSchool
            msg = "[skola] " + s.message
        else
            msg = s.message
        # svenskt oversattarlexikon?
        
        backend.submitContactForm(s.name, s.email, msg, isSOL).then( () ->
            s.showContact = true
            done()
        , err
        )
    s.subscribe = () ->
        msg = s.newsletterEmail + " vill bli tillagd på utskickslistan."
        backend.submitContactForm("Utskickslista", s.newsletterEmail, msg).then( () ->
            s.showNewsletter = true
            done()
        , err
        )


    

littb.controller "statsCtrl", ($scope, backend) ->
    s = $scope




    backend.getStats().then (data) ->
        s.statsData = data

    backend.getTitles(null, "popularity|desc").then (titleArray) ->
        s.titleList = titleArray

    backend.getEpub(30).then ({data, hits}) ->
        s.epubList = data






littb.controller "biblinfoCtrl", ($scope, backend) ->
    s = $scope
    limit = true
    s.showHit = 0
    s.searching = false
    s.wf = ""

    s.showAll = () ->
        limit = false
    
    s.increment = () ->
        limit = true
        s.entries?[s.showHit + 1] and s.showHit++
    s.decrement = () ->
        limit = true
        s.showHit and s.showHit--

    s.getEntries = () ->
        if limit
            return [s.entries?[s.showHit]]
        else 
            s.entries

    s.getColumn1 = (entry) ->
        pairs = _.toPairs entry
        splitAt = Math.floor pairs.length / 2
        _.fromPairs pairs[0..splitAt]

    s.getColumn2 = (entry) ->
        pairs = _.toPairs entry
        splitAt = Math.floor pairs.length / 2
        _.fromPairs pairs[(splitAt + 1)..]
    
    s.submit = () ->
        names = ["manus", "tryckt_material", "annat_tryckt", "forskning"]
        params = ("resurs=" + x for x in names when s[x])
        wf = s.wf if wf
        s.searching = true

        backend.getBiblinfo(params.join("&"), wf).then (data) ->
            s.entries = data
            s.num_hits = data.length
            s.searching = false
            
    s.submit()


littb.controller "authorInfoCtrl", ($scope, $location, $rootScope, backend, $routeParams, $http, $document, util, $route, authors, $q, $filter) ->
    s = $scope
    _.extend s, $routeParams

    if $route.current.$$route.isSla
        s.slaMode = true
        s.author = "LagerlofS"
        
    s.showpage = null
    s.show_large = false
    s.show_more = true

    if $location.search().dw
        s.isDramaweb = true
    
    s.getIntro = () ->
        unless s.authorInfo then return
        if s.isDramaweb
            s.authorInfo.dramawebben.intro or s.authorInfo.intro
        else
            s.authorInfo.intro
    
    s.getIntroAuthor = () ->
        unless s.authorInfo then return
        if s.isDramaweb and s.authorInfo.dramawebben.intro
            s.authorInfo.dramawebben.intro_author
        else
            s.authorInfo.intro_author

    s.normalizeAuthor = $filter('normalizeAuthor')

    s.titleSort = util.titleSort

    authors.then ([authorList, authorsById]) ->
        s.authorsById = authorsById

        # s.authorError = (s.normalizeAuthor s.author) not of s.authorsById

    s.showLargeImage = ($event) ->
        c.log "showLargeImage", s.show_large
        if s.show_large then return 
        s.show_large = true
        $event.stopPropagation()

        $document.one "click", (event) ->
            if event.button != 0 then return
            s.$apply () ->
                s.show_large = false
        return

    s.getTitleTooltip = (attrs) ->
        unless attrs then return
        return attrs.title unless attrs.shorttitle == attrs.title

    refreshRoute = () ->
        s.showpage = $location.path().split("/")[3]
        unless s.showpage then s.showpage = "introduktion"

    s.getUnique = (worklist) ->
        _.filter worklist, (item) ->
            "/" not in item.titlepath 
    
    s.getPageTitle = (page) ->
        {
           "titlar": "Verk i Litteraturbanken"
           "semer": "Mera om"
           "biblinfo": "Bibliografisk databas"
           "jamfor": "Textkritisk verkstad"
           "omtexterna": "Om texterna"
        }[page] or _.str.capitalize page

    s.getAllTitles = () ->
        [].concat s.groupedTitles, s.groupedWorks, s.groupedEditorWorks

    s.getUrl = (work) ->
        auth = (s.getWorkAuthor work.authors).author_id
        if work.mediatype == "epub" 
            url = "txt/epub/" + auth + "_" + work.work_title_id + ".epub"
        else if work.mediatype == "pdf"
            # url += "info"
            url = "txt/#{work.lbworkid}/#{work.lbworkid}.pdf"

        else
            url = "/forfattare/#{auth}/titlar/#{work.work_title_id}/"
            url += "sida/#{work.startpagename}/#{work.mediatype}"
        return url


    getHtml = (url) ->
        def = $q.defer()
        $http.get(url).success (xml) ->
            from = xml.indexOf "<body>"
            to = xml.indexOf "</body>"
            xml = xml[from...to + "</body>".length]
            def.resolve(_.str.trim xml)
        return def.promise


    if s.slaMode
        getHtml('/red/sla/OmSelmaLagerlofArkivet.html').then (xml) ->
            s.slaIntro = xml

    refreshExternalDoc = (page, routeParams) ->
        # sla hack
        c.log "refreshExternalDoc", page, routeParams.omtexternaDoc
        if s.slaMode
            if page == 'omtexterna' and not routeParams.omtexternaDoc
                doc = 'omtexterna.html'
            else if _.str.endsWith routeParams.omtexternaDoc, ".html"
                doc = routeParams.omtexternaDoc
            if doc
                url = '/red/sla/' + doc
            else 
                url = "/red/forfattare/#{s.author}/#{page}/index.html"
        else    
            # url = s.authorInfo[page]
            if page == "mer" then page = "semer"
            url = "/red/forfattare/#{s.author}/#{page}/index.html"
            c.log "url", url


        return unless url
        
        unless s.showpage in ["introduktion", "titlar"]
            getHtml(url).then (xml) ->
                s.externalDoc = xml
                if s.showpage == "omtexterna"
                    s.pagelinks = harvestLinks(s.externalDoc)
                else
                    s.pagelinks = null



    harvestLinks = (doc) ->
        elemsTuples = for elem in $(".footnotes .footnote[id^=ftn]", doc)
            [$(elem).attr("id"), $(elem).html()]

        s.noteMapping = _.fromPairs elemsTuples




    refreshRoute()

    s.$on "$routeChangeError", (event, current, prev, rejection) ->
        _.extend s, current.pathParams

        refreshRoute()  
        # refreshTitle()
        refreshExternalDoc(s.showpage, current.pathParams)
        # refreshBreadcrumb()
    

    s.getDataSource = () ->
        if s.showpage == "titlar"
            s.titleStruct
        else if s.showpage == "mer"
            c.log "showpage mer"
            s.moreStruct


    s.sortOrder = (works) ->
        works[0].sortkey

    s.hasMore = () ->
        (_.flatten _.map s.moreStruct, "data").length

    s.titleStruct = [
            label : "Tillgängliga verk"
            data : null
            showAuthor : false
            def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf", "main,scholar")
        ,
            label : "Dikter, noveller, essäer, etc. som ingår i andra verk"
            data : null
            showAuthor : false
            def : backend.getPartsInOthersWorks(s.author)
        ,
            label : "Som fotograf"
            data : null
            showAuthor : (work) -> work["authors"]
            def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf,etext-part,faksimil-part", "photographer")
        ,
            label : "Som illustratör"
            data : null
            showAuthor : (work) -> work["authors"]
            def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf,etext-part,faksimil-part", "illustrator")
        ,
            label : "Som utgivare"
            data : null
            showAuthor : (work) -> work["authors"]
            def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf,etext-part,faksimil-part", "editor")
        ,
            label : "Som översättare"
            data : null
            showAuthor : (work) -> work["authors"]
            def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf,etext-part,faksimil-part", "translator")
        ,
            label : "Som uppläsare"
            data : null
            showAuthor : (work) -> work["authors"]
            def : backend.getAudioList({reader : s.author})
        ,
            label : "Uppläsningar"
            data : null
            showAuthor : false
            def : backend.getAudioList({author_id : s.author})
            audioExtras : true
    ]
    s.getSortOrder = (obj) ->
        if obj.showAuthor is false
            return 'sortkey'
        else
            return ['authors[0].surname', 'sortkey']

    for item in s.titleStruct
        # TODO: error handling?
        do (item) ->
            item.def.then (data) -> 
                c.log "then", data
                item.data = data


    backend.getAuthorInfo(s.author).then (data) ->
        s.authorInfo = data

        refreshExternalDoc(s.showpage, $routeParams)



        s.moreStruct = [
                label : "Verk om #{s.authorInfo.full_name}"
                data : null
                def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf", null, true)
                showAuthor : (work) -> work["authors"]
            ,
                label : "Kortare texter om #{s.authorInfo.full_name}"
                data : null
                def : backend.getPartsInOthersWorks(s.author, true)
                showAuthor : (work) -> work["authors"] or work["work_authors"]
            ,
                label : "Som utgivare"
                data : null
                def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf", "editor", true)
                showAuthor : (work) -> work["authors"]
            ,
                label : "Som översättare"
                data : null
                def : backend.getTextByAuthor(s.author, "etext,faksimil,pdf", "translator", true)
                showAuthor : (work) -> work["authors"]
        ]

        for item in s.moreStruct
            do (item) ->
                item.def.then (data) -> item.data = data

        if not s.authorInfo.intro
            $location.url("/forfattare/#{s.author}/titlar").replace()
    , (data) ->
        c.log("authorinfo error", arguments)
        s.authorError = true


littb.controller "audioListCtrl", ($scope, backend, util, authors, $filter, $timeout, $location) ->
    s = $scope
    s.play_obj = null

    s.setPlayObj = (obj) ->
        s.play_obj = obj
        $location.search("spela", obj.file)

        $timeout( () -> 
            $("#audioplayer").get(0).play()
        )

    s.getAuthor = (author) ->
        [last, first] = author.name_for_index.split(",")

        (_.compact [last.toUpperCase(), first]).join ","

    authors.then ([authorList, authorsById]) ->
        s.authorsById = authorsById


    backend.getAudioList(sort_field: "order|asc").then (audioList) ->
        c.log "audioList", audioList
        s.fileGroups = _.groupBy audioList, "section"

        if $location.search().spela
            for item in audioList
                if item.file == $location.search().spela
                    s.setPlayObj(item)
        else
            s.play_obj = audioList[0]


        $("#audioplayer").bind 'ended', () ->
            s.$apply () ->
                if audioList[s.play_obj.i + 1]
                    s.setPlayObj(audioList[s.play_obj.i + 1])

    
littb.controller "epubListCtrl", ($scope, backend, util, authors, $filter, $q, $location) ->
    s = $scope
    s.searching = true
    s.authorFilter = $location.search().authorFilter

    if $location.search().qr
        backend.logQR($location.search().qr, $location.url())
        $location.search("qr", null)

    $q.all([authors, backend.getEpubAuthors()]).then ([[authorList, authorsById], epubAuthorIds]) ->
        s.authorsById = authorsById
        s.authorData = _.pick authorsById, epubAuthorIds
        s.authorData = _.orderBy s.authorData, (auth) ->
            transpose = (char) ->
                {"Ä": "Å", "Å" : "Ä", "ä" : "å", å: "ä"}[char] or char
            (_.map auth.name_for_index, transpose).join("")
        # s.authorIds = epubAuthorIds


    s.authorSelectSetup = {
        formatNoMatches: "Inga resultat",
        templateResult : (data) ->
            author = s.authorsById[data.id]
            unless author then return data.text

            firstname = ""
            if author.name_for_index.split(",").length > 1
                firstname = "<span class='firstname'>, #{author.name_for_index.split(',')[1]}</span>"

            return $ """
            <span>
                <span class="surname sc">#{author.surname}</span>#{firstname} <span class="year">#{$filter('authorYear')(author)}</span>
            </span>
            """

        templateSelection : (item) ->
            try
                return s.authorsById[item.id].surname
            catch e
                return "Välj författare"
    }

    s.genderSelectSetup = {

    }

    s.sortSelectSetup = {
        minimumResultsForSearch: -1,
        templateSelection : (item) ->
            "Sortering: " + item.text
    }

    window.has = (one, two) -> one.toLowerCase().indexOf(two.toLowerCase()) != -1
    s.rowFilter = (item) ->
        author = s.authorsById?[s.authorFilter]
        if author and author.author_id != item.authors[0].author_id then return false
        if s.filterTxt
            return false if not ((has item.authors[0].full_name, s.filterTxt) or (has (item.title), s.filterTxt))
        return true

    s.getAuthor = (row) ->
        [last, first] = row.authors[0].name_for_index.split(",")
        auth = (_.compact [last.toUpperCase(), first]).join ","
        if row.authors[0].type == "editor"
            auth += " (red.)"
        return auth

    # s.log = (filename) ->
        # return true

    s.log = (row) ->
        filename = s.getFilename(row)
        if not isDev
            backend.logDownload(row.authors[0].surname, encodeURIComponent(row.shorttitle), row.lbworkid)
        # location.href = "/txt/epub/#{filename}.epub"


    s.getFilename = (row) ->
        row.authors[0].author_id + '_' + (row.work_title_id or row.title_id)


    s.onAuthChange = (newVal) ->
        # hack for state issue with select2 broadcasting change event
        # at init, causing reset of location value
        if newVal == null 
            s.authorFilter = $location.search().authorFilter
        else
            s.refreshData()


    s.refreshData = (str) ->
        # | filter:rowFilter | limitTo:rowLimit | orderBy:sorttuple[0]:sorttuple[1]" 
        if s.authorFilter == null then return
        s.searching = true
        size = if s.filterTxt or s.showAll then 10000 else 30
        authorFilter = null
        if s.authorFilter != "alla"
            authorFilter = s.authorFilter

        backend.getEpub(size, s.filterTxt, authorFilter, s.sort).then ({data, hits}) ->
            s.searching = false
            s.rows = data
            s.hits = hits
            authors = _.map s.rows, (row) ->
                row.authors[0]

            # s.authorData = _.unique authors, false, (item) ->
            #     item.author_id
    
    util.setupHashComplex s,
        [
            key : "filter"
            scope_name : "filterTxt"
        ,
            key : "authorFilter"
        ,
            key : "sort",
            default: "epub_popularity|desc"
        ,
            key : "showAll"

        ]

    

    s.refreshData()


littb.controller "helpCtrl", ($scope, $http, util, $location) ->
    s = $scope
    url = "/red/om/hjalp/hjalp.html"
    $http.get(url).success (data) ->
        s.htmlContent = data
        s.labelArray = for elem in $("[id]", data)
            label = _.str.humanize($(elem).attr("name").replace(/([A-Z])/g, " $1"))

            label : label
            id : $(elem).attr("id")
            
        
littb.controller "newCtrl", ($scope, $http, util, $location, backend) ->

    s = $scope

    # backend.getTitles(null, "imported|desc", null, false, true).then (titleArray) ->
    #     s.titleList = titleArray

    #     s.titleGroups = _.groupBy titleArray, "imported"



littb.controller "aboutCtrl", ($scope, $http, util, $location, $routeParams) ->
    s = $scope
    # s.$watch ( () -> $routeParams.page), () ->
    #     c.log "$routeParams.page", $routeParams.page
    _.extend s, $routeParams
    s.$on "$routeChangeError", (event, current, prev, rejection) ->
        c.log "route change", current.pathParams
        _.extend s, current.pathParams



    s.page = $routeParams.page
    s.getPage = (page) ->
        return {
                "ide" : '/red/om/ide/omlitteraturbanken.html'
                "hjalp" : require("../views/help.html")
                "vision" : "/red/om/visioner/visioner.html"
                "kontakt" : require('../views/contactForm.html')
                "statistik" : require('../views/stats.html')
                "rattigheter" : '/red/om/rattigheter/rattigheter.html'
                "organisation" : '/red/om/ide/organisation.html'
                # "inenglish" : "/red/om/ide/inenglish.html",
                "english.html" : "/red/om/ide/english.html",
                "deutsch.html" : "/red/om/ide/deutsch.html",
                "francais.html" : "/red/om/ide/francais.html",
            }[page]

littb.controller "presentationCtrl", ($scope, $http, $routeParams, $location, util) ->
    s = $scope
    url = '/red/presentationer/presentationerForfattare.html'
    s.isMain = true
    $http.get(url).success (data) ->
        s.doc = data
        s.currentLetters = for elem in $("[id]", data)
            $(elem).attr("id")
        util.setupHash s, {"ankare" : (val) ->
            unless val
                $(window).scrollTop(0)
                return
            $(window).scrollTop($("##{val}").offset().top)
        }

littb.controller "omtexternaCtrl", ($scope, $routeParams) ->
    docPath = '/red/sla/omtexterna/'
    $scope.doc = docPath + ($routeParams['doc'] or 'omtexterna.html')
    


littb.filter "correctLink", () ->
    (html) ->
        wrapper = $("<div>").append html
        img = $("img", wrapper)
        img.attr "src", "/red/bilder/gemensamt/" + img.attr("src")
        return wrapper.html()


littb.controller "autocompleteCtrl", ($scope, backend, $route, $location, $window, $timeout, $modal, $http) ->
    s = $scope
    modal = null
    prevFilter = null
    s.close = () ->
        s.lbworkid = null
        s.$broadcast("blur")
        # s.show_autocomplete = false
        s.completeObj = null
        c.log "close modal", s.modal, s
        s.modal?.close()
        s.modal = null


    s.onSelect = (val) ->
        c.log("scope", s)
        if not isDev
            backend.logQuicksearch(prevFilter, val.label)
        
        ret = val.action?(s)
        if ret == false then return
        # if ret.then
        #     ret.then (val) ->


        s.close()
        if val.url
            $location.url(val.url)

    

    s.autocomplete = (val) ->
        if val
            prevFilter = val
            return backend.autocomplete(val).then (data) ->
                menu = [
                        label: "Start"
                        url : "/start"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Bibliotek"
                        url : "/bibliotek"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Epub"
                        url : "/epub"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Ljudarkivet"
                        url : "/ljudarkivet"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Sök"
                        url : "/sok"
                        alt: ["Sok"]
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Presentationer"
                        url : "/presentationer"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Dramawebben"
                        url : "/dramawebben"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Nytillkommet"
                        url : "/nytt"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Skolan"
                        url : "/skolan"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Skolan/lyrik"
                        url : "/skolan/lyrik"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Om"
                        url : "/om/ide"
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Hjälp"
                        url : "/om/hjalp"
                        alt : ["hjalp"]
                        typeLabel : "Gå till sidan"
                    ,
                        label: "Statistik"
                        url : "/om/statistik"
                        typeLabel : "Gå till sidan"

                ]

                if $route.current.$$route.controller == "readingCtrl"
                    menu.push 
                        label : "/id"
                        alt : ["id", "red"]
                        typeLabel: "[Red.]"
                        action : () ->
                            s.lbworkid = $(".reader_main").scope?().workinfo.lbworkid
                            return false
                    # ,
                    #     label : "/öppna"
                    #     alt : ["öppna"]
                    #     typeLabel: "[Red.]"
                    #     action : () ->
                    #         info = $(".reader_main").scope?().workinfo
                    #         win = window.open("littb-open://?lbworkid=#{info.lbworkid}&mediatype=#{info.mediatype}")
                    #         win.onload = () => win.close()
                    #         return false

                if $route.current.$$route.controller in ["readingCtrl", "authorInfoCtrl"]
                    key = {"readingCtrl" : "workinfo", "authorInfoCtrl" : "authorInfo"}[$route.current.$$route.controller]

                    menu.push
                        label : "/info"
                        alt : ["info", "db", "red"]
                        typeLabel: "[Red.]"
                        action : () ->
                            s.info = $("#mainview").scope?()[key]
                            return false
                        


                menu = _.filter menu, (item) ->
                    # if !isDev and item.typeLabel == "[Red.]" then return false
                    exp = new RegExp("^" + val, "gi")
                    # alt = new RegExp(val, "gi")
                    item.label.match(exp) or _.some item.alt?.map (item) ->
                        item.match(exp)
                return data.concat menu




    show = () ->
        # s.show_autocomplete = true

        s.modal = $modal.open
            templateUrl : "autocomplete.html"
            scope : s
            windowClass : "autocomplete"
            size : "sm"

        $timeout () ->
            s.$broadcast("focus")
        , 0
    # s.show_autocomplete = false
    s.$on "show_autocomplete", () ->
        show()
    $($window).on "keyup", (event) ->
        #tab
        if event.which == 83 and not $("input:focus,textarea:focus,select:focus").length
            s.$apply () ->
                show()



        else if event.which == 27 # escape
            s.$apply () ->
                s.close()



littb.controller "idCtrl", ($scope, backend, $routeParams, $location) ->
    s = $scope
    _.extend s, $routeParams
    s.id = s.id?.toLowerCase()
    s.titles = []
    unless _.str.startsWith s.id, "lb"
        s.titles = [s.id]
        s.id = ""

    backend.getTitles().then (titleArray) ->
        s.data = titleArray

    s.idFilter = (row) ->
        unless s.id then return true
        row.lbworkid == s.id

    s.rowFilter = (row) ->
        if not s.titles.length then return true
        return _.some _.map s.titles, (title) ->
            _.str.contains(row.titlepath.toLowerCase(), title?.toLowerCase()) or
                _.str.contains(row.title.toLowerCase(), title?.toLowerCase())


    s.textareaChange = (titles)  ->
        s.id = ''

        s.titles = _.map titles.split("\n"), (row) ->
            _.str.strip(row.split("–")[1] or row)

littb.controller "sourceInfoCtrl", ($scope, backend, $routeParams, $q, authors, $document, $location, $http) ->
    s = $scope
    {title, author} = $routeParams
    # _.extend s, $routeParams
    s.title = $routeParams.title
    s.author = $routeParams.author


    s.defaultErrataLimit = 8
    s.errataLimit = s.defaultErrataLimit
    s.isOpen = false
    s.show_large = false

    s.workinfoPromise.then () ->
        c.log "workinfo", s.workinfo
        prov = backend.getProvenance(s.workinfo)
        lic = backend.getLicense(s.workinfo)

        $q.all([prov, lic]).then ([provData, licenseData]) ->
            s.provenanceData = provData
            if provData.length
                provtmpl = "<a href='#{provData[0].link}'>#{provData[0].fullname}</a>"
            else
                provtmpl = ""
            s.licenseData = _.template(licenseData)({
                provenance: provtmpl
            })

        s.dramaweb = new Dramaweb(s.workinfo.dramawebben) if s.workinfo.dramawebben




    s.getValidAuthors = () ->
        unless s.authorById then return
        # _.filter s.workinfo?.author_idNorm, (item) ->
        #     item.id of s.authorById
        return s.workinfo?.authors

    s.toggleErrata = () ->
        s.errataLimit = if s.isOpen then 8 else 1000
        s.isOpen = !s.isOpen

    s.getUrl = (mediatype) ->
        if mediatype == "epub" 
            return s.workinfo?.epub.url
            
        else if mediatype == "pdf" 
            return s.workinfo?.pdf.url

        return "/forfattare/#{s.author}/titlar/#{s.title}/#{mediatype}"

    s.getOtherMediatypes = () ->
        (x for x in (s.workinfo?.mediatypes or []) when x != s.mediatype)

    s.getSourceImage = () ->
        if s.workinfo
            "/txt/#{s.workinfo.lbworkid}/#{s.workinfo.lbworkid}_small.jpeg"

    s.showLargeImage = ($event) ->
        if s.show_large then return 
        s.show_large = true
        $event.stopPropagation()

        $document.one "click", (event) ->
            if event.button != 0 then return
            s.$apply () ->
                s.show_large = false
        return

    
    s.getFileSize = (mediatype) ->
        # TODO: this is broken
        if not (s.workinfo and mediatype) then return
        size = s.workinfo[mediatype].file_size

        kb = size / 1024

        return (Math.round kb) + " KB"

    s.downloadFile = (url) ->
        window.location = url


    if not s.mediatype
        s.mediatype = s.workinfo.mediatypes[0]
    authors.then ([authorData, authorById]) ->
        s.authorById = authorById


    class Dramaweb
        constructor: (data) ->
            order =  [
                 "first_staged"
                 "number_of_pages"
                 "number_of_acts"
                 "number_of_roles"
                 "male_roles"
                 "female_roles"
                 "other_roles"
             ]
            @roles = data.roles
            @history = data.history
            tableData = _.omit data, "legacy_url", "roles", "history"
            @orderedData = _.orderBy(_.toPairs(tableData), (pair) -> order.indexOf(pair[0]))

        
        format: (key) ->
            {
                'roles': (val) -> val.join("<br>")
            }[key] or (val) -> val.toString()

        getLabel : (key) ->
            {
                roles: "Rollista"
                "first_staged" : "Urpremiär"
                "number_of_roles" : "Antal (totalt)"
                "male_roles" : "Antal (män)"
                "female_roles" : "Antal (kvinnor)"
                "other_roles" : "Antal (övriga)"
                "number_of_pages": "Antal sidor"
                "number_of_roles" : "Antal roller"
                "number_of_acts" : "Antal akter"
                "history" : "Uppsättningshistorik",



            }[key] or key

        # has_key

    
    



littb.controller "lexiconCtrl", ($scope, backend, $location, $rootScope, $q, $timeout, $modal, util, $window) ->
    s = $scope
    s.dict_not_found = null
    s.dict_searching = false

    modal = null

    s.keydown = (event) ->
        if event.keyCode == 40 # down arrow
            # TODO: this is pretty bad but couldn't be done using the typeahead directive
            if $(".input_container .dropdown-menu").is(":hidden")
                #typeaheadTrigger directive
                s.$broadcast "open", s.lex_article

        else if event.keyCode == 27 # escape
            s.lex_article = null    


    s.showModal = () ->
        c.log "showModal", modal
        s.lexemes = s.lex_article.lexemes
        unless modal
            s.$broadcast "blur"

            modal = $modal.open
                templateUrl : "so_modal_template.html"
                scope : s

            modal.result.then () ->
                s.closeModal()
            , () ->
                s.closeModal()


    s.clickX = () ->
        modal.close()

    s.closeModal = () ->
        s.lex_article = null
        s.lexid = null
        modal = null


    reportDictError = () ->
        s.$emit "notify", "Hittade inget uppslag"
        s.dict_searching = false

    s.lexid = null


    $rootScope.$on "search_dict", (event, lemma, id, doSearchId) ->
        c.log "search_dict event", lemma, id, doSearchId
        if doSearchId then s.lexid = false

        s.dict_searching = true

        def = backend.searchLexicon(lemma, id, false, doSearchId, true)
        def.catch () ->
            c.log "searchLexicon catch"
            reportDictError()

        def.then (data) ->
            c.log "searchLexicon then", data
            s.dict_searching = false

            result = data[0]
            for obj in data
                if obj.baseform == lemma
                    result = obj
                    continue

                    
            # c.log "searchId", id
            # s.lexid = if searchId then searchId else null
            s.lex_article = result
            if id
                s.lexid = id
            s.showModal()
            

    s.getWords = (val) ->
        c.log "getWords", val
        unless val then return
        s.dict_searching = true
        def = backend.searchLexicon(val, null, true)
        timeout = $timeout(angular.noop, 800)
        def.catch () ->
            s.dict_searching = false
            reportDictError()

        $q.all([def, timeout]).then () ->
            s.dict_searching = false
            

        return def



    util.setupHashComplex s, [
        key : "so"
        expr : "lex_article.baseform"
        val_in : (val) ->
            id = $location.search().lex
            # event = if id then "search_id" else "search_dict"
            c.log "val_in", val, id
            s.$emit "search_dict", val, id, false
        replace : false            
    ,
        key : "lex"
        scope_name : "lexid"
        replace : false

    ]

littb.controller "dramawebCtrl", ($scope, $location, $rootScope, backend, $routeParams, $http, $document, util, $route, authors, $q, $filter, $rootElement) ->
    s = $scope

    s.filters = {
        isChildrensPlay : false
    }

    updateRoute = () ->
        s.showpage = $location.path().split("/")[2] or "start"
        s.isStartPage = s.showpage == "start"
        # s.$root.dramasubpage = !s.isStartPage
        $rootScope._stripClass("drama")
        if !s.isStartPage
            $rootElement.addClass("drama-dramasubpage")
        
    updateRoute()
    s.$on "$routeChangeError", (event, current, prev, rejection) ->
        # _.extend s, current.pathParams
        updateRoute()


    util.setupHashComplex s,
            [
                key : "visa"
                scope_name : "listType"
                replace : false
                default : "pjäser"
        ]

    authors.then ([authorList, authorsById]) ->
        s.authorsById = authorsById
        s.authorList = authorList
    s.authorSelectSetup = {
        formatNoMatches: "Inga resultat",
        formatResult : (data) ->
            if not s.authorsById then return 
            author = s.authorsById[data.id]
            unless author then return data.text

            firstname = ""
            if author.name_for_index.split(",").length > 1
                firstname = "<span class='firstname'>, #{author.name_for_index.split(',')[1]}</span>"

            return """
            <span>
                <span class="surname sc">#{author.surname}</span>#{firstname} <span class="year">#{$filter('authorYear')(author)}</span>
            </span>
            """

        formatSelection : (item) ->
            try
                return s.authorsById[item.id].surname
            catch e
                return "Välj författare"

    }

    s.onRadioClick = (newType) ->
        c.log "onRadioClick", s.listType
        s.listType = newType

    s.listType = 'pjäser'

    s.formatInterval = ([from, width]) ->
        return "#{from}–#{width + from}"

    s.getAuthor = (author) ->
        [last, first] = author.name_for_index.split(",")

        if first
            first = "<span class='firstname'>#{first}</span>"
        else
            first = ""

        _.compact(["<span class='sc'>#{last}</span>", first]).join ","

    s.authorFilter = (author) ->
        if s.filters.gender and s.filters.gender != "all"
            return s.filters.gender == author.gender


        if s.filters.filterTxt
            searchstr = [author.full_name, author.birth.plain, author.death.plain]
                        .join(" ").toLowerCase()
            for str in s.filters.filterTxt.split(" ")
                if not searchstr.match(str) then return false


        return true

    s.getFilteredRows = () ->
        ret = _.filter s.rows, (item) -> 
            # if not (_.filter item.authors, (auth) -> auth.gender == s.filters.gender).length
            #     # return false
            if s.filters.gender and 
                (s.filters.gender != "all") and 
                item.authors[0].gender isnt s.filters.gender then return false


            if s.filters.author and s.filters.author != "all"
                if item.authors[0].author_id != s.filters.author then return false


            if s.filters.filterTxt 
                fullnames = _.map item.authors, (author) ->
                    [author.full_name, author.birth.plain, author.death.plain].join(" ")
                searchstr = fullnames.join(" ") + (item.title)
                searchstr = searchstr.toLowerCase()
                
                for str in s.filters.filterTxt.split(" ")
                    if not searchstr.match(str) then return false

            if s.filters.isChildrensPlay
                if not ("Barnlitteratur" in (item.keywords? or [])) then return false

            for [key, value] in _.toPairs(s.filters)
                if (_.isArray value) and value.length
                    [from, to] = value
                    from = from or 0
                    to = to or Infinity
                    if not (item.dramawebben?.hasOwnProperty key) then continue
                    n = Number(item.dramawebben[key])
                    if not (from <= n <= to ) then return false

            return true

        return ret
                

    backend.getDramawebTitles().then (data) ->
        s.rows = data

        s.filters = {
            gender : "",
            filterTxt : "",
            female_roles : [Infinity, 0]
            male_roles : [Infinity, 0]
            other_roles : [Infinity, 0]
            number_of_acts : [Infinity, 0]
            number_of_pages : [Infinity, 0]
            number_of_roles : [Infinity, 0]
            isChildrensPlay : false
        }

        findMinMax = ["female_roles", "male_roles", "other_roles", "number_of_acts", "number_of_pages", "number_of_roles"]
        for item in s.rows
            if not item.dramawebben then continue
            for key in findMinMax
                n = Number(item.dramawebben[key])
                if n < s.filters[key][0]
                    s.filters[key][0] = n
                if n > s.filters[key][1]
                    s.filters[key][1] = n
        s.sliderConf = {}
        for key in findMinMax
            [from, to] = s.filters[key]
            s.sliderConf[key] = {floor : from, ceil: to}

        authors = _.map data, (row) ->
            row.authors[0]

        s.authorData = _.uniq authors, false, (item) ->
            item.author_id

        s.authorData = _.sortBy s.authorData, "name_for_index"




