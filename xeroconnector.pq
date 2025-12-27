section XeroConnector;
/*
    Xero API Custom Connector for Power BI
    -------------------------------------
    - Supports Invoices, Journals, Manual Journals
    - OAuth 2.0 authentication
    - Handles page-based and offset-based pagination
    - Date filtering included for performance optimisation

    SECURITY NOTE:
    - client_id must be supplied locally
    - No credentials or tenant IDs are included in this repository
*/

client_id = error "CLIENT_ID_REQUIRED: Please supply your Xero app client_id before building the connector.";
required_scopes = "openid profile offline_access email accounting.transactions.read accounting.contacts.read";

windowWidth = 600;
windowHeight = 800;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
base_url = "https://api.xero.com";

// MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH
// NOTE: Scheduled refresh requires Power BI Gateway due to custom connector


// Data Source definition
XeroConnector = [
    TestConnection = (dataSourcePath) => {"XeroConnector.Contents"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];



// OAuth2 flow definition
StartLogin = (resourceUrl, state, display) =>
    let
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        bEnc = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_"),
        codeVerifier = bEnc(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier))),
        AuthorizeUrl = "https://login.xero.com/identity/connect/authorize?"
            & Uri.BuildQueryString(
                [
                    response_type = "code",
                    client_id = client_id,
                    scope = required_scopes,
                    state = state,
                    redirect_uri = redirect_uri,
                    code_challenge_method = "S256",
                    code_challenge = codeVerifier
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = plainTextCodeVerifier
        ];

FinishLogin = (context, callbackUri, state) => let 
    Parts = Uri.Parts(callbackUri)[Query] 
in TokenMethod(Parts[code], "authorization_code", context);


TokenMethod = (code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier
            & codeParameter
            & [
                client_id = client_id,
                grant_type = grant_type,
                redirect_uri = redirect_uri
            ],

        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            "https://identity.xero.com/connect/token",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded", 
                    #"Accept" = "application/json"
                ],
                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. 
//
// IMPORTANT - Credential matching is done based on the function's REQUIRED parameters.
// You can have as many different optional params, but the REQUIRED params must MATCH in every shared method.
//
// All data source functions associated to the same Data Source Kind must have a matching set of REQUIRED
// function parameters, including type, name, and the order in which they appear.
[DataSource.Kind = "XeroConnector", Publish="XeroConnector.UI"]
shared XeroConnector.Contents = Value.ReplaceType(Xero.Contents, type function (optional endpoint as text, optional tenantId as text, optional additionalParams as record) as any);

// pagination code
Xero.Contents = (optional endpoint as text, optional tenantId as text, optional additionalParams as record) =>
    let
        baseUrl = if endpoint = null then base_url & "/connections" else endpoint,
        pageSize = 100,
        maxPages = 5000,

// Detect pagination type
supportsPageParam =
    List.AnyTrue(
        List.Transform(
            {"invoices","contacts","payments","accounts","items"},
            each Text.Contains(Text.Lower(baseUrl), _)
        )
    ),
supportsOffsetParam =
    Text.Contains(Text.Lower(baseUrl), "journals") and not Text.Contains(Text.Lower(baseUrl), "manualjournals"),
isManualJournal =
    Text.Contains(Text.Lower(baseUrl), "manualjournals"),

        // Helper to get one page (or offset batch)
        GetPage = (index as number) =>
            let
        
            // For invoices or journals, apply date filters
            // Example date filters – adjust as needed
            dateFilter =
                if Text.Contains(Text.Lower(baseUrl), "invoices") then
                    "where=" &
                    Uri.EscapeDataString(
                        "Date >= DateTime(2018,01,01) AND Date <= DateTime(2030,12,31)"
                    )
                else if Text.Contains(Text.Lower(baseUrl), "journals") then
                    "where=" &
                    Uri.EscapeDataString(
                        "JournalDate >= DateTime(2018,01,01) AND JournalDate <= DateTime(2030,12,31)"
                    )
                else if Text.Contains(Text.Lower(baseUrl), "manualjournals") then
                    "where=" &
                    Uri.EscapeDataString(
                        "Date >= DateTime(2018,01,01) AND Date <= DateTime(2030,12,31)"
                    )
                else
                    null,

                queryParams =
                    if supportsPageParam then
                        // Use ?page=
                        (if dateFilter <> null then dateFilter & "&" else "") &
                        "page=" & Text.From(index)
                    else if supportsOffsetParam then
                        // Use ?offset=
                        "offset=" & Text.From((index - 1) * pageSize) & "&pageSize=" & Text.From(pageSize)
                    else
                        // No pagination
                        (if dateFilter <> null then dateFilter else ""),

                url =
                    if Text.Contains(baseUrl, "?") then
                        baseUrl & (if queryParams <> "" then "&" & queryParams else "")
                    else if queryParams <> "" then
                        baseUrl & "?" & queryParams
                    else
                        baseUrl,

                response = Web.Contents(
                    url,
                    [
                        Headers = [
                            #"Accept" = "application/json"
                        ] &
                        (if tenantId <> null then [#"xero-tenant-id" = tenantId] else [])
                    ]
                ),
                json = Json.Document(response)
            in
                json,

        // Pagination handling (page or offset)
GetAllPages =
    if supportsPageParam or supportsOffsetParam then
        List.Generate(
            () => [i = 1, data = GetPage(1)],
            each
                let
                    pageData = [data],
                    fieldNames =
                        if Value.Is(pageData, type record)
                        then Record.FieldNames(pageData)
                        else {},
                    keyCandidates = {"Invoices", "Contacts", "Payments", "Accounts", "Items", "Journals"},
                    intersection = try List.Intersect({ fieldNames, keyCandidates }) otherwise {},
                    key = if List.Count(intersection) > 0 then List.First(intersection) else null,
                    values = if key <> null then Record.Field(pageData, key) else {}
                in
                    List.Count(values) > 0 and [i] <= maxPages,
            each [i = [i] + 1, data = GetPage([i])],
            each [data]
        )
    else if isManualJournal then
        // Manual Journals: no pagination — only one request
        { GetPage(1) }
    else
        { GetPage(1) },

        // Combine results
        Combined =
            List.Combine(
                List.Transform(GetAllPages, (page) =>
                    if Value.Is(page, type record) then
                        let
                            keyCandidates = {"Invoices", "Contacts", "Payments", "Accounts", "Items", "Journals", "ManualJournals"},
                            key = List.First(List.Intersect({ Record.FieldNames(page), keyCandidates }), null)
                        in
                            if key <> null then Record.Field(page, key) else {}
                    else if Value.Is(page, type list) then
                        page
                    else
                        {}
                )
            ),

        output =
            if Value.Is(Combined, List.Type)
            then Table.FromList(Combined, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
            else Combined
    in
        output;
// end pagination code

// UI Export definition
XeroConnector.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = XeroConnector.Icons,
    SourceTypeImage = XeroConnector.Icons
];

XeroConnector.Icons = [
    Icon16 = {
        Extension.Contents("xero16.png"),
        Extension.Contents("xero20.png"),
        Extension.Contents("xero24.png"),
        Extension.Contents("xero32.png")
    },
    Icon32 = {
        Extension.Contents("xero32.png"),
        Extension.Contents("xero40.png"),
        Extension.Contents("xero48.png"),
        Extension.Contents("xero64.png")
    }
];