#�бq�̩��Umain�����}�l����
#�Цۦ���function setwd���|

install.packages("rJava")
install.packages("Rwordseg", repos="http://R-Forge.R-project.org")
install.packages("tm")
install.packages("tmcn", repos="http://R-Forge.R-project.org", type="source")
install.packages("wordcloud")
install.packages("XML")
install.packages("knitr")
install.packages("RCurl")
install.packages("rvest")
install.packages('stringr')
install.packages("cidian")
install.packages("devtools")
install.packages("RColorBrewer")
install_github("qinwf/cidian")
librery(cidian)
library(stringr)
library(rJava)
library(httr)
library(Rwordseg)
library(XML)
library(RCurl)
library(rvest)
library(knitr)
library(tm)
library(tmcn)
library(devtools)
library("slam")
library(wordcloud)
#----------------------------------------------------------------------------------
wordsCN<-function(x,...){
  words<-unlist(segmentCN(x))
  return(words)
}
##  Modified command "termFreq" on package tm
termFreqCN<-
  function (doc, control = list()) 
  {
    #stopifnot(inherits(doc, "TextDocument"), is.list(control))
    .tokenize <- control$tokenize
    if (is.null(.tokenize) || identical(.tokenize, "wordsCN")) 
      .tokenize <- wordsCN
    else if (identical(.tokenize, "MC")) 
      .tokenize <- MC_tokenizer
    else if (identical(.tokenize, "scan")) 
      .tokenize <- scan_tokenizer
    else if (NLP::is.Span_Tokenizer(.tokenize)) 
      .tokenize <- NLP::as.Token_Tokenizer(.tokenize)
    if (is.function(.tokenize)) 
      txt <- .tokenize(doc)
    else stop("invalid tokenizer")
    .tolower <- control$tolower
    if (is.null(.tolower) || isTRUE(.tolower)) 
      .tolower <- tolower
    if (is.function(.tolower)) 
      txt <- .tolower(txt)
    .removePunctuation <- control$removePunctuation
    if (isTRUE(.removePunctuation)) 
      .removePunctuation <- removePunctuation
    else if (is.list(.removePunctuation)) 
      .removePunctuation <- function(x) do.call(removePunctuation, 
                                                c(list(x), control$removePunctuation))
    .removeNumbers <- control$removeNumbers
    if (isTRUE(.removeNumbers)) 
      .removeNumbers <- removeNumbers
    .stopwords <- control$stopwords
    if (isTRUE(.stopwords)) 
      .stopwords <- function(x) x[is.na(match(x, stopwords(meta(doc, 
                                                                "language"))))]
    else if (is.character(.stopwords)) 
      .stopwords <- function(x) x[is.na(match(x, control$stopwords))]
    .stemming <- control$stemming
    if (isTRUE(.stemming)) 
      .stemming <- function(x) stemDocument(x, meta(doc, "language"))
    or <- c("removePunctuation", "removeNumbers", "stopwords", 
            "stemming")
    nc <- names(control)
    n <- nc[nc %in% or]
    for (name in sprintf(".%s", c(n, setdiff(or, n)))) {
      g <- get(name)
      if (is.function(g)) 
        txt <- g(txt)
    }
    if (is.null(txt)) 
      return(setNames(integer(0), character(0)))
    dictionary <- control$dictionary
    tab <- if (is.null(dictionary)) 
      table(txt)
    else table(factor(txt, levels = dictionary))
    if (names(tab[1])=="") tab <- tab[-1]
    bl <- control$bounds$local
    if (length(bl) == 2L && is.numeric(bl)) 
      tab <- tab[(tab >= bl[1]) & (tab <= bl[2])]
    nc <- nchar(names(tab), type = "chars")
    wl <- control$wordLengths
    lb <- if (is.numeric(wl[1])) wl[1] else 3
    ub <- if (is.numeric(wl[2])) wl[2] else Inf
    tab <- tab[(nc >= lb) & (nc <= ub)]
    storage.mode(tab) <- "integer"
    class(tab) <- c("term_frequency", class(tab))
    tab
  }

## Useful for TermDocumentMatrix
TermDocumentMatrix_classes <-
  c("TermDocumentMatrix", "simple_triplet_matrix")
## Useful for TermDocumentMatrix
.TermDocumentMatrix <-
  function(x, weighting)
  {
    x <- as.simple_triplet_matrix(x)
    if(!is.null(dimnames(x)))
      names(dimnames(x)) <- c("Terms", "Docs")
    class(x) <- TermDocumentMatrix_classes
    ## <NOTE>
    ## Note that if weighting is a weight function, it already needs to
    ## know whether we have a term-document or document-term matrix.
    ##
    ## Ideally we would require weighting to be a WeightFunction object
    ## or a character string of length 2.  But then
    ##   dtm <- DocumentTermMatrix(crude,
    ##                             control = list(weighting =
    ##                                            function(x)
    ##                                            weightTfIdf(x, normalize =
    ##                                                        FALSE),
    ##                                            stopwords = TRUE))
    ## in example("DocumentTermMatrix") fails [because weightTfIdf() is
    ## a weight function and not a weight function generator ...]
    ## Hence, for now, instead of
    ##   if(inherits(weighting, "WeightFunction"))
    ##      x <- weighting(x)
    ## use
    if(is.function(weighting))
      x <- weighting(x)
    ## and hope for the best ...
    ## </NOTE>
    else if(is.character(weighting) && (length(weighting) == 2L))
      attr(x, "weighting") <- weighting
    else
      stop("invalid weighting")
    x
  }
##  Modified command "TermDocumentMatrix" on package tm
##  and defined "TermDocumentMatrixCN"
TermDocumentMatrixCN<-
  function (x, control = list()) 
  {
    stopifnot(is.list(control))
    tflist <- lapply(unname(content(x)), termFreqCN, control)
    tflist <- lapply(tflist, function(y) y[y > 0])
    v <- unlist(tflist)
    i <- names(v)
    allTerms <- sort(unique(as.character(if (is.null(control$dictionary)) i else control$dictionary)))
    i <- match(i, allTerms)
    j <- rep(seq_along(x), sapply(tflist, length))
    docs <- as.character(meta(x, "id", "local"))
    if (length(docs) != length(x)) {
      warning("invalid document identifiers")
      docs <- NULL
    }
    m <- simple_triplet_matrix(i = i, j = j, v = as.numeric(v), 
                               nrow = length(allTerms), ncol = length(x), dimnames = list(Terms = allTerms, 
                                                                                          Docs = docs))
    bg <- control$bounds$global
    if (length(bg) == 2L && is.numeric(bg)) {
      rs <- row_sums(m > 0)
      m <- m[(rs >= bg[1]) & (rs <= bg[2]), ]
    }
    weighting <- control$weighting
    if (is.null(weighting)) 
      weighting <- weightTf
    .TermDocumentMatrix(m, weighting)
  }


#---------------------------------------------------------------------------------------------------------
geturl <- function( page_start, page_end, range,data ){

for( i in page_start:page_end){    # in�᭱�������}�᭱���Ʀr �ΨӧP�_�X����ĴX��
  tmp <- paste(i, '.html', sep='')
  url <- paste('http://www.ptt.cc/bbs/Gossiping/index', tmp, sep='')
  url
  
  url<-GET(url, config=set_cookies("over18"="1"),encoding = 'UTF-8')      #   over18 = 1 �O�]���K������18������ �p�G�S���o��
                                                                          #   �|�]��cookie���P�_ ��������n�T�{�O�_��18��������
  url.list<-c()  
 
   
  html <- htmlParse(url,encoding='UTF-8')
  temp.list <- xpathSApply(html, "//div[@class='title']/a[@href]", xmlAttrs) #�Ȧs�C�g�峹���}

  
  
  Responsetime<-xpathSApply(html, "//div[@class='r-ent']", xmlValue)    #���C�g�峹���^����
  Responsetime
  
  for ( x in c(1:20))    #�C����20�g�峹 �o��n�`�N�׶}�̷s�������_�h�|�X�� �]���̷s���������@�w�|��20�g�峹
  {
    k<-substr(Responsetime[x],5,8)   #k���^���� ���O�Ochr���O
    k<-gsub("\t","",k)
    k<-gsub("\n","",k)
    
    grepl("�z",k)
    num<-strtoi(k, base = 0L)    #num���C�g�^����
    if( is.na(num) )
      num<-0
    if(grepl("�z",k))
      num<-9999
    
    if( !is.na( num ) && (num > range) ) 
    {
     
      url.list[length(url.list)+1] <- temp.list[x]
        
    }
    
   
    #browser()
      
    
  }    

  #url.list <- xpathSApply(html, "//div[@class='title']/a[@href]", xmlAttrs)
  url.list
  data_ <- rbind(data, paste('www.ptt.cc', url.list, sep=''))
  #
  # x <- c(1, 2, 3)
  # y <- c(10, 20, 30)
  # rbind(x, y) 
  # [,1] [,2] [,3]
  # x    1    2    3
  # y   10   20   30
  
  #browser()
}
  
  eval.parent(substitute( data<-data_ )  )  

}
#-----------------------------------------------------------------------------------------------------
getdoc <- function(line){
  
  #ROC<-��<title>���إ��� �V ����ʬ�A�ۥѪ��ʬ����</title>"
  #regexpr(�����إ���",ROC)
  #[1] 8
  
  start <- regexpr('www', line)[1]
  
  end <- regexpr('html', line)[1]
 
  
  if(start != -1 & end != -1){
    url <- substr(line, start, end+3)
    url<- paste( 'http://',url, sep='' )
   
    html <- GET(url, config=set_cookies("over18"="1"), encoding='UTF-8')
    
    html <- htmlParse(html,encoding='UTF-8')
  
    name<- xpathSApply( html, "//head/title", xmlValue)
 
    doc <- xpathSApply( html, "//div[@id='main-content']", xmlValue)
  
    name
    
    
    
    #name <- strsplit(url, '/')[[1]][6]    
    
    #gsub( 'html','txt', name)
    
    name = paste(name, '.txt', sep='')       #��X��.txt��
    name = str_replace_all( name, '\\<',"")  #�ɦW�����\��?�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\>',"")  #�ɦW�����\��?�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\?',"")  #�ɦW�����\��?�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\:',"")  #�ɦW�����\��:�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\�G',"")  #�ɦW�����\��:�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\"',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\/',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\,',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\�A',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\|',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    name = str_replace_all( name, '\\\\',"")  #�ɦW�����\��"�� ���峹���D�|�� �p�G�������峹���D���ɦW �n�N�S���r���h��
    write(doc, name  )   
    #browser()
    
  }      
}


#------------------------------------------------------------------------------------------------ 
 remove_trash<- function(word)       
 {
   
   return (gsub("[A-Za-z0-9]", "", word))
   
 }
 
 #-----------------------------�H�W���������---------------------------------------------------

text_mining<- function(name){      

 d.corpus <- Corpus( DirSource(name), list(language = NA))  # �Q��tm���M���Ū�����쪺���  "5��19~5��15"����Ƨ��W�� �n�]�w�ثe���u�@�ؿ�
 d.corpus <- tm_map(d.corpus, removePunctuation) #�M�����I�Ÿ�
 d.corpus <- tm_map(d.corpus, removeNumbers)    #�M���Ʀr
 d.corpus <- tm_map(d.corpus, remove_trash  )   #�M���@�ǭ^��r���� a-z A-Z 0-9   remove���۩w�q�禡
 #words <- readLines("ptt.scel")

 #installDict("C:/Users/user/Desktop/R final_project/ptt.scel","ptt",dicttype = "scel")   #�s�Wptt�`�λy�i�r������U�_��
 #installDict("C:/Users/user/Desktop/R final_project/����.scel","Internet",dicttype = "scel")
 #installDict("C:/Users/user/Desktop/R final_project/���y�U�y.scel","idiom",dicttype = "scel")
 #installDict("C:/Users/user/Desktop/R final_project/aaaa.scel","ccc",dicttype = "scel")
 #installDict("C:/Users/user/Desktop/R final_project/2017-5.txt","2017",dicttype = "text")
 #listDict()                                                                              #�d�ݥثe�����Ǧr��
 
 #uninstallDict("ccc") #�M�Ŧr��  


 #---------------------------------
 #segmentCN��Ƹ���
 #segmentCN(strwords,  
 #analyzer = get("Analyzer", envir = .RwordsegEnv),  
 #nature = FALSE, nosymbol = TRUE,  
 #returnType = c("vector", "tm"), isfast = FALSE,  
 #outfile = "", blocklines = 1000)  
 #strwords�G����y�l
 #analyzer�G���R��java��H
 #nature�G�O�_�ѧO���ժ����ʡ]�ʵ��B�ήe���^
 #nosymbol:�O�_�O�d�y�l�Ÿ�
 #returnType�G�q�{�O�@�Ӧr�Ŧ�A�]�i�H�O�s����L���˦��A��ptm�榡�A�H��tm�]���R
 #isfast�G���_���N���������@�ӭӦr�šA���O���N���O�d�y�l�A�u�O�_�y
 #outfile�G�p�G��J�O�@�Ӥ��A��󪺸��|�Oԣ
 #blocklines�G�@�檺�̤jŪ�J�r�ż�
 #--------------------------------------
 
 
 d.corpus <- tm_map(d.corpus[1:length( d.corpus) ], segmentCN, nature = TRUE)  #�����p�W                        
 

 d.corpus <- tm_map(d.corpus, function(sentence) {                #�u���W��
   noun <- lapply(sentence, function(w) {
     w[names(w) == "n"]
   })
   unlist(noun)
 })
 d.corpus <- Corpus(VectorSource(d.corpus))
 
 inspect(d.corpus )
 
    #     append �i���J�b�쥻�r��᭱                          ���Φr�ŴN���O�y�U���@��:�@�� �i�� �γ\�o�������Ҭ��_�����Ƥ��R�S���U
 myStopWords <- c(stopwordsCN())  #�]���C�g�峹���@�w�|���o�Ǧr �ӳo�Ǧr��ڭ̨S���U
 myStopWords <- append( myStopWords, c("�峹","���}","���D","�K��","�F��","��]","���G","�ɭ�","�s�D","���D","�s��", "�ɶ�", "�o�H", "��~", "�@��","�F��") )        
 myStopWords <- append( myStopWords,c("��a","�C��","����","�U��","�k��","���|","�Pı","����","�p��","�k�l","�k�l","�@��","�Ʊ�","�H�a","�O��","�k��") )           #�s�W�@��ptt�峹���D�`�X�{���r�h����
 myStopWords <- append( myStopWords,c("�Q��","�߱o","����","����","�ݨ�","�u��","�x�~","�Яq","���R","���i") )
 d.corpus <- tm_map(d.corpus, removeWords, myStopWords) #�h���_��
 #d.corpus
 
 #head(myStopWords, 50) #�i�ݦ������_��  50���e50��
 tdm <- TermDocumentMatrixCN(d.corpus, control = list(wordLengths = c(2, Inf)))  #�ন�x�} ���׬�2���~�� �o�̨ϥκ��ʹ��Ѫ�
                                                                                 #�Ӥ��O�M�󤺪�TermDocumentMatrix
 #str(d.corpus)
 #str(tdm)
 tdm
 inspect(tdm[1:20, 1:3])
 #inspect(d.corpus)
 
 
 
 m1 <- as.matrix(tdm)
 v <- sort(rowSums(m1), decreasing = TRUE)
 d <- data.frame(word = names(v), freq = v)
 
 wordcloud(d$word, d$freq, min.freq = 150, random.order = F, ordered.colors = F, 
           colors = rainbow(length(row.names(m1))))
 
 write.csv( v,"freq.csv")
 
}
 
 #--------------------------------main--------------------------------------------------------------------------------------
 data<- list()
 page_start<-as.integer(readline(prompt = "�п�J���}�}�Y�p https://www.ptt.cc/bbs/Gossiping/index23091.html ���� 23091: "))
 page_end<-as.integer(readline(prompt = "�п�J���}����:"))
 range<-as.integer(readline(prompt = "�п�J�n�쪺�^���ƭn�b�h�֥H�W���峹:"))
 
 setwd("C:/Users/user/Desktop/R final_project/new") #�ۦ�]�w�n�s���ɮת���Ƨ�
 
 geturl( page_start,page_end,range,data )
 sapply(data, getdoc)   #��X
 
 setwd("C:/Users/user/Desktop/R final_project/") #�ۦ�]�w�s���ɮ׸�Ƨ����W�@�h��m
 Foldername <- as.character(readline(prompt = "�п�J�s���ɮ׸�Ƨ����W��:"))
 text_mining(Foldername)
 
 
 
 
 
 
 
 
