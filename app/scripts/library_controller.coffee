littb.controller "libraryCtrl", ($scope, backend, util, $timeout, $location, authors, $rootElement, $anchorScroll, $q, $filter) ->
    s = $scope
    s.titleSearching = false
    s.authorSearching = true
    s.showPopular = true
    s.showPopularAuth = true
    s.showInitial = true
    s.show_more = $location.search().avancerat?
    # s.rowByLetter = {}
    s.filters = _.omitBy {
        'main_author.gender': $location.search()['kön']
        keywords : $location.search()['keywords']?.split(",")
        languages : $location.search()['languages']?.split(",")
        mediatypes : $location.search()['mediatypes']?.split(",")
    }, _.isNil


    s.normalizeAuthor = $filter('normalizeAuthor')

    s.getTitleTooltip = (attrs) ->
        unless attrs then return
        return attrs.title unless attrs.showtitle == attrs.title

    s.filterTitle = (row) ->    
        auths = (_.map row.authors, (auth) ->
            return auth.full_name
        ).join(" ")

        exprs = s.rowfilter.split(" ")

        return _.every exprs, (expr) ->
            new RegExp(expr, "i").test((row.itemAttrs.title + " " + row.itemAttrs.shorttitle + " " + auths + " " + row.itemAttrs.imprintyear + " "))

    isIE = detectIE()
    c.log "isIE", isIE

    if isIE and isIE < 12
        s.rowLimit = 30        

    
    backend.getAboutAuthors().then (data) ->
        console.log("getAboutAuthors")
        s.aboutAuthors = data

    aboutDef = $q.defer()
    s.onAboutAuthorChange = _.once ($event) ->
        console.log("$event", s.about_authors_filter, $location.search().about_authors_filter)
        s.about_authors_filter = $location.search().about_authors_filter?.split(",") or []
        aboutDef.resolve()

    $q.all([aboutDef.promise, authors]).then () ->
        c.log("after authors, about")
        $timeout( () ->
            $(".about_select").select2()
        , 0)


    s.filterAuthor = (author) ->
        exprs = s.rowfilter?.split(" ")

        return _.every exprs, (expr) ->
            pseudonym = (_.map author.pseudonym, "full_name").join(" ")
            new RegExp(expr, "i").test((author.full_name + pseudonym))

    getPopularTitles = () ->
        s.titleSearching = true
        def = backend.getTitles(null, "popularity|desc").then (titleArray) ->
            s.titleSearching = false
            s.popularTitles = titleArray
            s.titleByPath = _.groupBy titleArray, (item) ->
                return item.titlepath

            return titleArray

    s.resetView = () ->
        s.showInitial = true
        s.showPopularAuth = true
        s.showPopular = true
        s.showRecent = false

        s.filters = {}
        s.about_authors_filter = []
        $timeout () ->
            $(".gender_select, .keyword_select, about_select").select2()
        , 0
        s.filter = ""
        s.rowfilter = ""
        s.all_titles = null
        s.audio_list = null

        if not s.popularTitles
            getPopularTitles()


    s.hasMediatype = (titleobj, mediatype) ->
        mediatype in (_.map titleobj.mediatypes, "label")

    s.pickMediatypes = (titleobj, mediatypeLabels) ->
        _.filter titleobj.mediatypes, (item) -> item.label in mediatypeLabels


    s.getTitleUrl = (titleobj) ->
        mediatype = s.sortMedia(titleObj.mediatype)[0]


    s.sortMedia = (list) ->
        order = ['etext', 'faksimil', 'epub', 'pdf']
        return _.intersection(order,list).concat(_.difference(list, order))

    s.getTitleId = (row) ->
        row.work_title_id

    s.getUniqId = (title) ->
        unless title then return
        title.lbworkid + (title.titlepath.split('/')[1] or "")
        

    s.authorRender = () ->
        c.log "authorRender"
        # s.$apply () ->
        if $location.search()['author']
            auth = s.authorsById[$location.search()['author']]
            s.authorClick(null, auth)

            s.$emit("listScroll", $location.search()['author'])


    s.titleRender = () ->
        if $location.search()['title']
            # fetchWorks().then () ->
            title = s.titleByPath?[$location.search()['title']][0]
            s.titleClick(null, title)
            id = s.getUniqId title
            s.$emit("listScroll", id)
                


    # use timeout to make sure the page shows before loading authors
    # $timeout () ->
    authors.then ([authorList, authorsById]) ->
        console.log("authors.then")
        s.authorsById = authorsById
        s.authorData = _.filter authorList, (item) ->
            item.show
        s.authorSearching = false

    backend.getPopularAuthors().then (auths) ->
        s.popularAuthors = auths

        
    # , 10
        
    s.getAuthorData = () ->
        if s.showPopularAuth
            return s.popularAuthors
        # else
        #     filters = getKeywordTextfilter()
        #     if _.toPairs(filters).length
        #         return _.filter s.authorData, (auth) ->
        #             conds = []
        #             if filters['provenance.library'] == "Dramawebben"
        #                 conds.push(auth.dramaweb?)

        #             if filters['main_author.gender']
        #                 conds.push(auth.gender == filters['main_author.gender'])

        #             return _.every conds

        else if s.showInitial
            return s.authorData
        else
            # s.authorData
            return s.currentAuthors

    s.searchTitle = () ->
        c.log "searchTitle", s.filter
        s.selectedAuth = null
        s.selectedTitle = null
        s.rowfilter = s.filter
        # if s.rowfilter or _.toPairs(getKeywordTextfilter()).length
        if _.toPairs(getKeywordTextfilter()).length or $location.search().about_authors_filter
            s.showInitial = false
            s.showPopularAuth = false
            s.showPopular = false
            if s.rowfilter
                fetchTitles()
                fetchAudio()
            fetchWorks()
            # if not (_.toPairs(getKeywordTextfilter()).length or s.about_authors_filter?.length)
            #     fetchAudio()
            if not isDev
                backend.logLibrary(s.rowfilter)
        else
            s.resetView()



    fetchTitles = () ->
        # unless s.filter then return
        backend.getParts(s.rowfilter, true, getKeywordTextfilter()).then (titleArray) ->
            s.all_titles = titleArray
    
    fetchAudio = () ->
        backend.getAudioList({string_filter : s.rowfilter, sort_field: "title.raw|asc", partial_string : true}).then (titleArray) ->
            s.audio_list = titleArray

    getKeywordTextfilter = () ->
        {
          "gender": "main_author.gender:female",
          "keywords": [
            "provenance.library:Dramawebben"
          ],
          "about_authors": [
            "StrindbergA"
          ],
          "languages" : {
            "modernized:true",
            "proofread:true",
            "language:deu"
          }
          "mediatypes" : [
            'has_epub:true'
          ]
        }

        c.log("gender filter", s.filters["gender"])
        if s.filters["main_author.gender"] == "all"
            delete s.filters["main_author.gender"]
        kwList = _.values(s.filters.keywords).concat(_.values(s.filters.languages), _.values(s.filters.mediatypes))
        text_filter = {}
        for kw in kwList
            [key, val] = kw.split(":")
            if key == 'main_author.gender' and val == "all" then continue
            if text_filter[key]
                text_filter[key].push(val)
            else
                text_filter[key] = [val]
        return _.extend _.omit(s.filters, "keywords", "languages", "mediatypes"), text_filter

    fetchWorks = () ->
        s.titleSearching = true
        include = "lbworkid,titlepath,title,title_id,work_title_id,shorttitle,mediatype,searchable,authors.author_id,work_authors.author_id,authors.surname,authors.type,startpagename,has_epub"
        # last true in args list is for partial_string match
        text_filter = getKeywordTextfilter()
        text_filter = null unless _.toPairs(text_filter).length
        about_authors = $location.search().about_authors_filter
        def = backend.getTitles(about_authors, null, s.filter, !!about_authors, false, s.rowfilter, include, text_filter).then (titleArray) ->
            s.titleArray = titleArray
            authors.then () ->
                s.currentAuthors = _(titleArray)
                                        .map (work) -> (s.authorsById[auth.author_id] for auth in work.authors when not auth.type)
                                        .flatten()
                                        .uniqBy("author_id")
                                        .sortBy("name_for_index")
                                        .value()

            # s.titleGroups = titleGroups
            s.titleByPath = _.groupBy titleArray, (item) ->
                return item.titlepath
            s.titleSearching = false

            return titleArray

        return def
    
    s.showAllWorks = () ->
        s.showPopular = false
        s.showRecent = false
        s.filter = ""
        s.rowfilter = ""
        s.titleArray = null
        fetchWorks()
    
    s.popClick = () ->
        s.showRecent = false
        s.showPopular = true
        if not s.popularTitles
            getPopularTitles()

    s.fetchRecent = () ->
        s.showPopular = false
        s.showRecent = true
        s.filter = ""
        s.rowfilter = ""
        s.titleArray = null

        dateFmt = (datestr) ->
            months = "januari,februari,mars,april,maj,juni,juli,augusti,september,oktober,november,december".split(",")
            [year, month, day] = datestr.split("-")
            return [Number(day), months[month - 1], year].join(" ")

        s.titleSearching = true
        backend.getTitles(null, "imported|desc,sortfield|asc", null, false, true).then (titleArray) ->
            s.titleSearching = false
            # s.titleArray = titleArray

            s.titleGroups = _.groupBy titleArray, "imported"

            output = []
            for datestr, titles of s.titleGroups
                # TODO: fix locale format, 'femte maj 2017'
                # output.push {isHeader : true, label : moment(datestr, "YYYY-MM-DD").format()}
                output.push {isHeader : true, label : dateFmt(datestr)}
                output = output.concat (_.sortBy titles, ["sortfield"])

            s.titleArray = output

    s.getUrl = (row, mediatype) ->
        author_id = row.authors[0].workauthor or row.authors[0].author_id

        if mediatype == "epub" 
            url = "txt/epub/" + author_id + "_" + row.work_title_id + ".epub"
        else if mediatype == "pdf"
            url = "txt/#{row.lbworkid}/#{row.lbworkid}.pdf"
        else
            url = "/forfattare/#{author_id}/titlar/#{s.getTitleId(row)}/" +
                 "sida/#{row.startpagename}/#{mediatype}"

        return url


    s.authorClick = ($event, author) ->
        unless s.selectedAuth == author
            s.selectedAuth?._collapsed = false
        
        s.selectedAuth = author

        $location.search("author", author.author_id)
        author._infoSearching = true
        backend.getAuthorInfo(author.author_id).then (data) ->
            author._collapsed = true
            author.data = data
            author._infoSearching = false

    s.authorHeaderClick = ($event, author) ->
        if s.selectedAuth == author and author._collapsed
            author._collapsed = false
            $event?.stopPropagation()

    s.titleHeaderClick = ($event, title) ->
        if s.selectedTitle == title and title._collapsed
            title._collapsed = false
            $event?.stopPropagation()

    s.titleClick = ($event, title) ->
        unless s.selectedTitle == title
            s.selectedTitle?._collapsed = false

        s.selectedTitle = title
        s.selectedTitle._collapsed = true
        $location.search("title", title.titlepath)


    s.getPartAuthor = (part) ->
        part.authors?[0] or part.work_authors[0]


    if $location.search().nytillkommet
        s.fetchRecent()
    else
        if $location.search().filter
            s.filter = $location.search().filter
        s.searchTitle()
    # if $location.search().keyword
    #     s.selectedKeywords = $location.search().keyword?.split(",")

    util.setupHashComplex s,
        [
            key : "filter"
            # scope_name : "rowfilter"
            replace : false
        ,
            key : "nytillkommet"
            scope_name : "showRecent"
        ,
            key : "kön",
            expr: "filters['main_author.gender']"
            default: "all"
        ,
            key : "languages",
            expr: "filters.languages",
            val_in : (val) ->
                val?.split(",")
            val_out : (val) ->
                val?.join(",")
        ,
            key : "keywords"
            expr : "filters.keywords"
            val_in : (val) ->
                val?.split(",")
            val_out : (val) ->
                val?.join(",")
        ,
            key : "mediatypes"
            expr : "filters.mediatypes"
            val_in : (val) ->
                val?.split(",")
            val_out : (val) ->
                val?.join(",")
        ,
            key : "about_authors_filter"
            val_in : (val) ->
                val?.split(",")
            val_out : (val) ->
                val?.join(",")
        ,
            key: "avancerat",
            expr: "show_more"

        ]

    s.listVisibleTitles = () ->
        if s.showInitial and s.showPopular
            s.popularTitles
        else
            return s.titleArray
