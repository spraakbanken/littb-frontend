// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS201: Simplify complex destructure assignments
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
littb.controller("readingCtrl", function($scope, backend, $routeParams, $route, $location, util, SearchWorkData, debounce, $timeout, $rootScope, $document, $window, $rootElement, authors, $modal, $templateCache, $http, $q, $filter) {
    let args, key, searchData, val;
    const s = $scope;
    s.isEditor = false;
    s._ = {humanize : _.humanize};

    s.isDramaweb = $location.hash() === "dw";    

    $window.scrollTo(0, 0);
    let t = $.now();

    let {title, author, mediatype, pagename} = $routeParams;
    _.extend(s, (_.pick($routeParams, "title", "author", "mediatype")));

    if ("ix" in $routeParams) {
        s.isEditor = true;
        s.pageix = Number($routeParams.ix);
        mediatype = (s.mediatype = {'f' : 'faksimil', 'e' : 'etext'}[s.mediatype]);
    }

    s.pageToLoad = pagename;

    s.searchData = (searchData = null);
    s.loading = true;
    s.first_load = false;
    const onFirstLoad = _.once(() =>
        $timeout( () => $("html, body").animate({ scrollLeft: "1000px"}, 1000)
        , 0)
    );
    s.showPopup = false;
    s.error = false;
    s.show_chapters = false; // index modal

    s.normalizeAuthor = $filter('normalizeAuthor');

    const h = $(window).height();
    let w = $(window).width();

    s.fontSizeFactor = h / 900;
    $rootScope._night_mode = false;
    s.isFocus = false;
    s.showFocusBar = true;
    s.isOcr = () => $location.search().ocr != null;

    s.activateFocus = function() {
        s.isFocus = true;
        return s.showFocusBar = true;
    };

    s.hasSearchable = function(authorid) {
        if (!authorid) { return; }
        return (s.authorById != null ? s.authorById[author].searchable : undefined);
    };

    s.closeFocus = event =>
        // event.stopPropagation()
        s.isFocus = false
    ;


    s.incrFontSize = function(event, fac) {
        event.stopPropagation();
        return s.fontSizeFactor += fac;
    };

    s.getFontSizeFactor = function() {
        if (s.isFocus) { return s.fontSizeFactor; } else { return 1; }
    };

    s.getTransform = function() {
        let to;
        if (!s.isFocus) { return {}; }
        const prefixes = ["", "-webkit-", "-o-", "-moz-", "-ms-"];
        const val = `scaleX(${s.fontSizeFactor}) scaleY(${s.fontSizeFactor})`;
        const addPrefixes = rule => _.map(prefixes, p => p + rule);

        const out = {};
        for ([to, t] of Array.from(_.zip((addPrefixes("transform-origin")), (addPrefixes("transform"))))) {
            out[t] = val;
            out[to] = "top";
        }

        return out;
    };

    s.openModal = () => s.show_about = true;
        

    s.onPartClick = function(startpage) {
        s.gotopage(startpage);
        s.showPopup = false;
        return s.show_chapters = false;
    };

    s.resetHitMarkings = () =>
        ["markee_from", "markee_to", "x", "y", "height", "width"].map((key) =>
            (s[key] = null))
    ;
    
    const thisRoute = $route.current;

    const changeHit = function(newHit) {
        c.log("newHit", newHit);
        const from_id = newHit.highlights[0].wid;
        const to_id = _.last(newHit.highlights).wid;
        s.gotopage(newHit.highlights[0].n);
        s.markee_from = from_id;
        s.markee_to = to_id;
        return $location.search("hit_index", newHit.order);
    };

    s.nextHit = () => searchData.next().then(changeHit);
    
    s.prevHit = () => searchData.prev().then(changeHit);

    s.close_hits = function() {
        searchData.reset();
        s.resetHitMarkings();
        return s.show_search_work = false;
    };

    const onKeyDown = function(event) {
        if (event.metaKey || event.ctrlKey || event.altKey) { return; }
        return s.$apply(function() {
            switch (event.which) {
                case 39: 
                    if ((navigator.userAgent.indexOf("Firefox") !== -1) || (($rootElement.prop("scrollWidth") - $window.scrollX) === $($window).width())) {
                        return s.nextPage();
                    }
                    break;
                case 37: 
                    if ($window.scrollX === 0) {
                        return s.prevPage();
                    }
                    break;
            }
        });
    };

    $document.on("keydown", onKeyDown);

    s.getPage = function() {
        if (s.isEditor) {
            return $route.current.pathParams.ix;
        } else {
            return $route.current.pathParams.pagename || s.startpage;
        }
    };
    

    s.setPage = function(ix) {
        s.pageix = ix;
        return s.pageToLoad = s.pagemap[`ix_${s.pageix}`];
    };

    s.getStep = () => (s.workinfo != null ? s.workinfo.stepmap[s.pageix] : undefined) || (s.workinfo != null ? s.workinfo.pagestep : undefined) || 1;

    
    s.nextPage = function(event) {
        if (event != null) {
            event.preventDefault();
        }
        if (s.isEditor) {
            s.pageix = s.pageix + s.getStep();
            // s.pageix = s.pageix + 1
            s.pageToLoad = s.pageix;
            return;
        }
        if (!s.endpage) { return; }
        const newix = s.pageix + s.getStep();
        // newix = s.pageix + 1
        if ((`ix_${newix}`) in s.pagemap) {
            return s.setPage(newix);
        }
    };
        // else
        //     s.setPage(0)
    
    s.prevPage = function(event) {
        if (event != null) {
            event.preventDefault();
        }
        // unless s.pagemap then return
        if (s.isEditor) {
            s.pageix = s.pageix - s.getStep();
            // s.pageix = s.pageix - 1
            s.pageToLoad = s.pageix;
            return;
        }
        const newix = s.pageix - s.getStep();
        // newix = s.pageix - 1
        if ((`ix_${newix}`) in s.pagemap) {
            return s.setPage(newix);
        } else {
            return s.setPage(0);
        }
    };

    
    s.isBeforeStartpage = function(pageix) {
        if (s.isEditor) { return false; }
        if (!s.pagemap) { return; }
        const startix = s.pagemap[`page_${s.startpage}`];
        return pageix <= startix;
    };

    s.getFirstPageUrl = function() {
        const { search } = window.location;
        if (s.isEditor) {
            return `/editor/${$routeParams.lbid}/ix/0/${$routeParams.mediatype}` + search;
        } else {
            return `/forfattare/${author}/titlar/${title}/sida/${s.startpage}/${mediatype}` + search;
        }
    };
    
    s.getPrevPageUrl = function() {
        if (!s.pagemap) { return; }
        const newix = s.pageix - s.getStep();
        // newix = s.pageix - 1
        if ((`ix_${newix}`) in s.pagemap) {
            const page = s.pagemap[`ix_${newix}`];
            return `/forfattare/${author}/titlar/${title}/sida/${page}/${mediatype}`;
        } else {
            return "";
        }
    };
    
    s.getNextPageUrl = function() {
        if (!s.endpage) { return; }
        if (s.pageix === s.pagemap[`page_${s.endpage}`]) { return; }
        const newix = s.pageix + s.getStep();
        // newix = s.pageix + 1
        if ((`ix_${newix}`) in s.pagemap) {
            const page = s.pagemap[`ix_${newix}`];
            return `/forfattare/${author}/titlar/${title}/sida/${page}/${mediatype}`;
        } else {
            return "";
        }
    };
    
    s.getLastPageUrl = function() {
        if (s.isEditor) {
            return `/editor/${$routeParams.lbid}/ix/${s.endIx}/${$routeParams.mediatype}`;
        } else {
            return `/forfattare/${author}/titlar/${title}/sida/${s.endpage}/${mediatype}`;
        }
    };

    s.getPageUrl = function(page) {
        if (!page) { return ""; }
        const search = __guard__($location.url().split("?"), x => x[1]);
        let suffix = "";
        if (search) {
            suffix = `?${search}`;
        }

        return `/forfattare/${author}/titlar/${title}/sida/${page}/${s.mediatype}` + suffix;
    };

    s.gotopage = function(page, event) {
        s.showGotoInput = false;
        c.log("preventDefault", page);
        if (event != null) {
            event.preventDefault();
        }
        const ix = s.pagemap[`page_${page}`];
        if (s.isEditor) {
            s.pageix = ix;
            return s.pageToLoad = ix;
        } else {
            return s.setPage(ix);
        }
    };

    s.onGotoClick = function() {
        if (s.showGotoInput) {
            s.showGotoInput = false;
            return;
        }
        s.showGotoInput = true;
        return $timeout(() => s.$broadcast("focus"),
        0);
    };

    s.toStartPage = function(event) {
        if (event != null) {
            event.preventDefault();
        }
        if (s.isEditor) {
            s.pageix = 0;
            return s.pageToLoad = 0;
        } else {
            return s.gotopage(s.startpage);
        }
    };

    s.mouseover = function(event) {
        c.log("mouseover");
        return s.showPopup = true;
    };


    // onClickOutside = () ->
    //     s.$apply () ->
    //         s.showPopup = false

    // $document.on "click", onClickOutside


    s.getTooltip = function(part) {
        if (part.navtitle !== part.showtitle) { return part.showtitle; }
    };

    const partStartsOnPage = part => s.pagemap[`page_${part.startpagename}`] === s.pageix;

    const getAllCurrentParts = function() {
        if (!s.workinfo) { return; }
        return _.filter(s.workinfo.parts, function(part) {
            const startix = s.pagemap[`page_${part.startpagename}`]; 
            const endix = s.pagemap[`page_${part.endpagename}`]; 
            return (s.pageix <= endix) && (s.pageix >= startix);
        });
    };

    const findShortest = parts =>
        _.min(parts, function(part) {
            const startix = s.pagemap[`page_${part.startpagename}`]; 
            const endix = s.pagemap[`page_${part.endpagename}`]; 
            return endix - startix;
        })
    ;

    const getLastSeenPart = function(findIndex, filterEnded, ignoreCurrent) {
        const maybePart = _.last(_.dropRightWhile(s.workinfo.partStartArray, function(...args1) { 
            let startix;
            let part;
            [startix, part] = Array.from(args1[0]);
            if (part === ignoreCurrent) { return true; } // always go back a part
            const endix = s.pagemap[`page_${part.endpagename}`]; 
            if (findIndex === endix) { return false; } // shortcut
            if (filterEnded && (endix < findIndex)) { return true; } // toss out ended parts
            return (startix > findIndex);
        })
        ); //or (endix <= findIndex) 

        if (maybePart) { return maybePart[1]; }

        // we're could be on a page between two parts
        // so find the last part that ended
        const decorated = _.map(s.workinfo.partStartArray, function(...args1) { 
            let i;
            let part;
            [i, part] = Array.from(args1[0]);
            return [findIndex - s.pagemap[`page_${part.endpagename}`], part];
    });

        const [diff, part] = Array.from(_.min(decorated, function(...args1) {
            let num;
            let part;
            [num, part] = Array.from(args1[0]);
            if (num < 0) { return 10000;
            } else { return num; }
        }));

        return part;
    };




    s.getCurrentPart = function() {
        if (!s.workinfo) { return; }

        // there are no parts on this page
        if (!getAllCurrentParts().length) { return; } 

        const partStartingHere = _.find(s.workinfo.partStartArray, function(...args1) { 
            const [i, part] = Array.from(args1[0]);
            return i === s.pageix;
        });

        return (partStartingHere != null ? partStartingHere[1] : undefined) || getLastSeenPart(s.pageix, true);
    };


    s.getNextPartUrl = function() {
        if (!s.workinfo) { return; }

        const findIndex = s.pageix + 1; // should always go one page fwd

        const next = _.first(_.dropWhile(s.workinfo.partStartArray, function(...args1) { let part;
        let i; [i, part] = Array.from(args1[0]); return i < findIndex; }));

        if (!next) { return ""; }
        const [i, newPart] = Array.from(next);

        return s.getPageUrl(newPart.startpagename);
    };

    s.getPrevPartUrl = function() {
        if (!s.workinfo) { return; }
        if (!s.workinfo.partStartArray.length) { return; }

        const [i, firstpart] = Array.from(s.workinfo.partStartArray[0]);
        if (s.pageix <= i) { return; } // disable prev if we're before first part

        /*
        firstParts = _.filter s.workinfo.partStartArray, ([startix]) ->
            * all parts that start at the same page as the first part
            s.workinfo.partStartArray[0][0] == startix

        shortestFirstpart = findShortest(_.map(firstParts, _.last))

        * are we at the first part?
        * i.e are we before the end of the first part?
        if (s.pageix <= s.pagemap["page_" + shortestFirstpart.endpagename])
            return null
        current = s.getCurrentPart()
        */
        const prev = getLastSeenPart(s.pageix - 1, false);

        if (!prev) { return ""; }

        return s.getPageUrl(prev.startpagename);
    };


    s.toggleParallel = () => s.isParallel = !s.isParallel;

    s.supportsParallel = function() {
        if (!s.workinfo) { return; }
        return Array.from(s.workinfo.mediatypes).includes('etext') && Array.from(s.workinfo.mediatypes).includes('faksimil');
    };

    s.getValidAuthors = function() {
        if (!s.authorById) { return; }
        return (s.workinfo != null ? s.workinfo.authors : undefined);
    };
        // _.filter s.workinfo?.authors, (item) ->
        //     item.id of s.authorById

    authors.then(function(...args1) {
        const [authorData, authorById] = Array.from(args1[0]);
        return s.authorById = authorById;
    });


    s.size = $location.search().size || 3;
    c.log("s.size", s.size);
    
    const recalcCoors = function(val) {
        if (!s.x) { return; }
        return s.coors = (() => {
            const result = [];
            const iterable = s.x.split("|");
            for (var i = 0; i < iterable.length; i++) {
                const item = iterable[i];
                const pairs = _.toPairs(_.pick(s, "x", "y", "height", "width"));
                result.push(_.fromPairs(_.map(pairs, function(...args1) {
                    let key, val;
                    [key, val] = Array.from(args1[0]);
                    return [key, val.split("|")[i].split(",")[s.size - 1]];
            })));
            }
            return result;
        })();
    };
    let chapter_modal = null;
    let about_modal = null;
    util.setupHashComplex(s, [{
            scope_name : "markee_from",
            key : "traff",
            replace : false
        }
        , {
            scope_name : "markee_to",
            key : "traffslut",
            replace : false
        }
        , {
            key : "x",
            replace : false,
            post_change: recalcCoors
        }
                
        , {
            key : "y",
            replace : false,
            post_change: recalcCoors
        }
        , {
            key : "width",
            replace : false,
            post_change: recalcCoors
        }
        , {
            key : "height",
            replace : false,
            post_change: recalcCoors
        }
        , {
            key : "parallel",
            scope_name : "isParallel"
        }
        , {   
            key : "fokus",
            scope_name : "isFocus",
            post_change(val) {
                return $rootScope._focus_mode = val;
            }
        }
        ,
            {key : "border"}
        ,
            {key: "show_search_work"}
        , {
            key : "om-boken",
            scope_name : "show_about",
            default: "no",
            post_change(val) {
                if (val) {
                    about_modal = $modal.open({
                        templateUrl : "sourceInfoModal.html",
                        scope : s,
                        windowClass : "about"
                    });


                    return about_modal.result.then(() => s.show_about = false
                    , () => s.show_about = false);
                } else {
                    if (about_modal != null) {
                        about_modal.close();
                    }
                    return about_modal = null;
                }
            }
        }
            
        , {
            key : "innehall",
            scope_name : "show_chapters",
            post_change(val) {
                if (val) {

                    chapter_modal = $modal.open({
                        templateUrl: "chapters.html",
                        scope: s,
                        windowClass : "chapters"
                    });

                    return chapter_modal.result.then(() => s.show_chapters = false
                    , () => s.show_chapters = false);

                } else {
                    if (chapter_modal != null) {
                        chapter_modal.close();
                    }
                    return chapter_modal = null;
                }
            }
        }

    ]);
    
    // s.showFocusBar = s.isFocus
    if (mediatype === "faksimil") {
        util.setupHashComplex(s, [{
                key: "storlek",
                scope_name : "size",
                val_in : Number,
                // val_out : (val) ->
                //     val + 1
                default : 3,
                post_change: recalcCoors
            }
                    
        ]);
    }



    const watches = [];
    watches.push(s.$watch("pageToLoad", function(val) {
        // c.log "pagename", val
        let url;
        if (val == null) { return; }
        s.displaynum = val;
        if (s.isEditor) {
            url = `/editor/${$routeParams.lbid}/ix/${val}/${$routeParams.mediatype}`;
        } else {
            url = `/forfattare/${author}/titlar/${title}/sida/${val}/${mediatype}`;
        }

        const prevpath = $location.path();

        const loc = $location.path(url);
        if (!s.isEditor && !_.str.contains(prevpath, "/sida/")) {
            c.log("replace", prevpath);
            return loc.replace();
        }
    })
    );
    // ), 300, {leading:true})

    s.isDefined = angular.isDefined;
    s.getOverlayCss = function(obj) {
        if (!s.overlayFactors) { return {}; }
        const fac = s.overlayFactors[s.size - 1];
        return {
            left: (fac * obj.x) + 'px',
            top: (fac * obj.y) + 'px'
            // width : fac * obj.w
            // height : fac * obj.h
        };
    };

    const initSourceInfo = function() {
        let params;
        if (s.isEditor) {
            params = {
                lbworkid : $routeParams.lbid
            };
        } else {
            params = {
                "titlepath" : title,
                "authorid" : author
            };
        }

        const def = backend.getSourceInfo(params, mediatype);
        s.workinfoPromise = def; 
        def.then(function(workinfo) {
            s.workinfo = workinfo;
            s.pagemap = workinfo.pagemap;
            const steps = [];
            if (s.etextPageMapping == null) { s.etextPageMapping = {}; }

            if (mediatype === "faksimil") {

                s.sizes = new Array(5);
                for (let i of Array.from(s.workinfo.faksimil_sizes)) {
                    s.sizes[i] = true;
                }
            }


            s.startpage = workinfo.startpagename;
            s.endpage = workinfo.endpagename;
            if ((pagename == null)) {
                s.pagename = (pagename = s.startpage);
            }
            s.pageix = s.pagemap[`page_${pagename}`];
            return c.log("s.pagename", pagename);
        });

        return def;
    };


    

    const downloadPage = function(pageix) {
        const filename = _.str.lpad(pageix, 5, "0");
        const id = $routeParams.lbid || s.workinfo.lbworkid;
        const url = `txt/${id}/res_${filename}.html`;
        const def = backend.getHtmlFile(url);
        def.then(function(html) {
            // since we use hard line breaks, soft hyphen needs to be replaced by actual hyphen
            const xmlSerializer = new XMLSerializer();
            const childNodes = [];
            for (let child of Array.from(html.data.firstChild.childNodes)) {
                childNodes.push(xmlSerializer.serializeToString(child));
            }
            s.etext_html = childNodes.join("").replace(/­/g, "-"); // there's a soft hyphen in there, trust me
            return s.etext_html;
        });

        return def;
    };


    const infoDef = initSourceInfo();
    const fetchPage = function(ix) {
        if (mediatype === "etext") {
            return downloadPage(ix);
        } else {
            let basename;
            const id = $routeParams.lbid || s.workinfo.lbworkid;
            if (s.isEditor) {
                basename = ix + 1;
            } else {
                basename = s.workinfo.filenameMap[ix];
            }
            const filename = _.str.lpad(basename, 4, "0");
            s.url = `/txt/${id}/${id}_${s.size}/${id}_${s.size}_${filename}.jpeg`;
            const def = $q.defer();
            def.resolve();
            return def.promise;
        }
    };


    const loadPage = val =>
        infoDef.then(function() {
            c.log("loadPage", val);
            if ($route.current.controller !== 'readingCtrl') { 
                c.log("resisted page load");
                return;
            }

            s.error = false;

            if (!s.isEditor && !isDev) {
                backend.logPage(s.pageix, s.workinfo.lbworkid, mediatype);
            }

            if ($location.search().sok) {
                s.$broadcast("popper.open.searchPopup");
            }


            
            let promise = null;
            if (s.isEditor) {
                s.pageix = Number(val);
                promise = fetchPage(s.pageix);
            } else { 
                s.pagename = val;
                s.pageix = s.pagemap[`page_${s.pagename}`];
                promise = fetchPage(s.pageix);
            }

            promise.then(function(html) {
                c.log("onFirstLoad");
                s.first_load = true;
                s.loading = false;
                return onFirstLoad();
            });

            if ((mediatype === "faksimil") && s.workinfo.searchable) {
                return backend.fetchOverlayData(s.workinfo.lbworkid, s.pageix).then(function(...args1) {
                    const [overlayHtml, overlayFactors] = Array.from(args1[0]);
                    s.overlayFactors = overlayFactors;
                    return s.overlayHtml = overlayHtml;
                });
            }
        }

        , function(err) {
            c.log("page load error", err, $location.path());


            if (s.isEditor) {
                fetchPage(Number(val)).then(function() {});
                s.loading = false;
                return s.first_load = true;

            } else {
                s.error = true;
                if (!isDev) {
                    return backend.logError("reader", {
                        path: $location.path()
                    });
                }
            }
    })
    ;

    s.setSize = function(index) {
        c.log("setsize", index);
        s.size = index;
        return loadPage(s.getPage());
    };

    s.isSizeDisabled = function(isIncrement) {
        if (s.isEditor) { return false; }
        if (isIncrement) {
            return !(s.sizes != null ? s.sizes[((s.size - 1) || 0) + 1] : undefined);
        } else {
            return !(s.sizes != null ? s.sizes[((s.size - 1) || 0) - 1] : undefined);
        }
    };


    watches.push(s.$watch("getPage()", debounce(loadPage, 200, {leading : false})));

    s.$on("$destroy", function() {
        c.log("destroy reader");
        $document.off("keydown", onKeyDown);
        return (() => {
            const result = [];
            for (w of Array.from(watches)) {
                result.push(w());
            }
            return result;
        })();
    });

//# ORD OCH SAK
    backend.ordOchSak(author, title).then(function(ordOchSak) {
        s.ordOchSakAll = ordOchSak;
        s.$watch("pagename", updateOrdOchSak);
        return updateOrdOchSak();
    }
    , function(error) {});
        // c.log 'failed to get ord och sak', error
    
    var updateOrdOchSak = function() {
        if (!s.ordOchSakAll || !s.pagename) { return; }
        return s.ordOchSakPage = (Array.from(s.ordOchSakAll).filter((entry) => entry.forklaring && Array.from(entry.pages).includes(s.pagename)));
    };
    
    //# TODO
    //s.markOosEntry = (entry) ->
    //    for id in entry.ids
    //        fromSpan = $(".etext #"+id.from)
    //        toSpan = $(".etext #"+id.to)
    //        all = fromSpan.nextUntil(toSpan).add(fromSpan).add(toSpan)
    //        all.addClass("markee")
    //
    //s.unmarkOosEntries = () ->
    //    $(".etext .markee").removeClass("markee")
    
//# END ORD OCH SAK

    s.$on("img_expand", function(evt, src) {
        let img_modal;
        c.log("img expand!", src);

        s.activeSrc = src;
        return img_modal = $modal.open({
            templateUrl : "img_full.html",
            scope : s,
            windowClass : "img_full",
            size : "lg"
        });
    });



    //# START SEARCH

    s.getCleanUrl = () => $location.url().split("?")[0];

    s.hasActiveSearch = () => $location.search().s_query && !(searchData != null ? searchData.isSearching : undefined);

    s.searchData = (searchData = new SearchWorkData(s));

    c.log("outside params", $location.search());
    const query = $location.search().s_query;
    if (query) {
        args = {
            mediatype
        };
        s.search_query = query;
        const getScopeVars = function(args) {
            const output = {};
            if (args.word_form_only) {
                output.lemma = true;
            }
            if (args.prefix) {
                output.prefix = true;
            }
            if (args.suffix) {
                output.suffix = true;
            }
            if (args.prefix && args.suffix) {
                args.infix = true;
            }
            return output;
        };

        const object = $location.search();
        for (key in object) {
            val = object[key];
            if (_.str.startsWith(key, "s_")) {
                const k = key.slice(2);
                args[k] = val;
            }
        }

        // _.extend s, getScopeVars(args)

            
        searchData.newSearch(args);
        searchData.current = Number($location.search().hit_index || 0);
        searchData.get(searchData.current).then(changeHit);
    }

    s.onGotoHitInput = function() {
        if (s.showGotoHitInput) {
            s.showGotoHitInput = false;
            return;
        }
        s.showGotoHitInput = true;
        return $timeout(() => s.$broadcast("focus"),
        0);
    };


    s.onGotoHit = function(hit) {
        if (hit > searchData.total_hits) {
            return;
        }
        s.showGotoHitInput = false;
        hit = Number(hit - 1);
        c.log("hit", hit);
        searchData.current = hit;
        return searchData.get(hit).then(changeHit);
    };



    s.openSearchWorks = function() {
        s.show_search_work = !s.show_search_work; 
        return $timeout(() => s.$broadcast('focus.search_work')
        , 0);
    };


    return s.searchWork = function(query) {
        c.log("searchWork", query);

        s.$root.prevSearchState = null;
        // size = $location.search().storlek

        args = {
            query,
            lbworkid : s.workinfo.lbworkid,
            prefix: $location.search().prefix,
            suffix: $location.search().suffix,
            // infix: $location.search().infix
            mediatype
        };
        if (!$location.search().lemma) {
            args.word_form_only = true;
        }
        const searchArgs = {};
        for (key in args) {
            val = args[key];
            searchArgs[`s_${key}`] = val;
        }


        const prevArgs = {};
        const object1 = $location.search();
        for (key in object1) {
            val = object1[key];
            if (!(_.str.startsWith(key, "s_"))) { prevArgs[key] = val; }
        }

        $location.search(_.extend({}, prevArgs, searchArgs));
        c.log("searchArgs", searchArgs, prevArgs);


        searchData.newSearch(args);
        searchData.current = 0;
        return searchData.get(0).then(function(hit) {
            c.log("hit", hit);
            if (!hit) { return; }
            return changeHit(hit);
        });
    };
});

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}