% member5_app_frontend/queryGeminiAgent.m
function advice = queryGeminiAgent(varargin)
%QUERYGEMINIAGENT
% DristhiSetu AI Agent for Diabetic Retinopathy Triage & Patient Education.
% Works with DristhiSetu UI - handles screening levels, lesion counts,
% patient Q&A, and multimodal retinal image analysis.

    % ============================================================
    % CONFIGURATION
    % ============================================================
    % Enter your Google AI Studio Gemini API Key below
    GEMI_API_KEY = ''; 
    
    % Model string (gemini-2.5-flash or gemini-1.5-flash)
    MODEL_NAME = 'gemini-2.5-flash';

    % ============================================================
    % CHECK INPUT
    % ============================================================
    if nargin < 1
        advice = ['DristhiSetu AI is ready. Type a screening level ' ...
            '(0 to 4), ask a question, or attach a retinal image. ' ...
            '(Health education only - not a diagnosis.)'];
        return;
    end

    % ============================================================
    % 1. PARSE INPUTS
    % ============================================================
    diagStr = '';
    question = '';
    imagePath = '';

    if nargin >= 1
        if isDiagnosis(varargin{1})
            diagStr = char(string(varargin{1}));
        else
            question = char(string(varargin{1}));
        end
    end

    if nargin >= 2
        secondArg = char(string(varargin{2}));
        if exist(secondArg, 'file') == 2
            imagePath = secondArg;
        else
            question = secondArg;
        end
    end

    if nargin >= 3
        question = char(string(varargin{2}));
        thirdArg = char(string(varargin{3}));
        if exist(thirdArg, 'file') == 2
            imagePath = thirdArg;
        end
    end

    % ============================================================
    % 2. ONLINE AGENT - GEMINI REST API
    % ============================================================
    onlineAdvice = '';

    if ~isempty(GEMI_API_KEY) && exist('webwrite', 'file') == 2
        try
            systemPrompt = [ ...
                'You are DristhiSetu AI, an expert, empathetic health education and triage assistant for Diabetic Retinopathy (DR). ' ...
                'Your goal is to provide clear, patient-friendly guidance based on DR screening levels ' ...
                '(0: No DR, 1: Mild NPDR, 2: Moderate NPDR, 3: Severe NPDR, 4: Proliferative DR/PDR) and lesion findings. ' ...
                'Always include: 1. What this means. 2. Exact doctor urgency. 3. Daily care. 4. Diet and targets. 5. Danger signs. ' ...
                'Format cleanly using bold headers and concise bullet points. ' ...
                'End with: "(Health education only - not a diagnosis. Please show this report to an eye doctor.)"' ...
            ];

            userMessage = '';
            if ~isempty(diagStr)
                userMessage = sprintf('Screening Result / Findings: %s\n', diagStr);
            end
            if ~isempty(question)
                userMessage = sprintf('%sPatient Context / Findings: %s', userMessage, question);
            end
            if isempty(userMessage) && ~isempty(imagePath)
                userMessage = 'Please analyze the attached retinal image and provide patient-friendly guidance.';
            end

            url = sprintf(['https://generativelanguage.googleapis.com/' ...
                'v1beta/models/%s:generateContent?key=%s'], MODEL_NAME, GEMI_API_KEY);

            textPart = struct('text', userMessage);
            parts = textPart;

            % Multimodal Image Payload Attachment
            if ~isempty(imagePath)
                fid = fopen(imagePath, 'rb');
                if fid == -1, error('Could not open the selected image file.'); end
                imageBytes = fread(fid, Inf, '*uint8');
                fclose(fid);

                imageBase64 = matlab.net.base64encode(imageBytes);
                [~, ~, ext] = fileparts(imagePath);
                switch lower(ext)
                    case {'.jpg', '.jpeg'}, mimeType = 'image/jpeg';
                    case '.png',            mimeType = 'image/png';
                    case '.webp',           mimeType = 'image/webp';
                    case '.bmp',            mimeType = 'image/bmp';
                    otherwise,              mimeType = 'image/jpeg';
                end

                imagePart = struct('inline_data', struct('mime_type', mimeType, 'data', imageBase64));
                parts = [textPart, imagePart];
            end

            payload = struct('system_instruction', struct('parts', struct('text', systemPrompt)), ...
                             'contents', struct('parts', parts));

            options = weboptions('MediaType', 'application/json', 'Timeout', 20);
            res = webwrite(url, jsonencode(payload), options);

            if ~isempty(res) && isfield(res, 'candidates') && ~isempty(res.candidates)
                onlineAdvice = char(res.candidates(1).content.parts(1).text);
            end

        catch ME
            warning('DristhiSetu:GeminiError', 'Gemini request failed: %s. Using local knowledge base.', ME.message);
            onlineAdvice = '';
        end
    end

    if ~isempty(onlineAdvice)
        advice = onlineAdvice;
        return;
    end

    % ============================================================
    % 3. OFFLINE CLINICAL KNOWLEDGE BASE
    % ============================================================
    if ~isempty(diagStr)
        advice = buildAdviceHtml(diagStr, question);
    else
        advice = simpleAnswer(question);
        advice = [advice ' (Health education only - not a diagnosis. Please show this report to a doctor.)'];
    end
end

% ============================================================
% HELPER FUNCTIONS (LOCAL OFFLINE ENGINE)
% ============================================================
function tf = isDiagnosis(s)
    st = char(string(s));
    if ~isempty(regexp(strtrim(st), '^[0-4]$', 'once')), tf = true; return; end
    lo = lower(st);
    tf = contains(lo,'level') || contains(lo,'grade') || ...
         contains(lo,'npdr')  || contains(lo,'pdr')   || ...
         contains(lo,'retinopathy') || contains(lo,'proliferative') || ...
         contains(lo,'mild')  || contains(lo,'moderate') || ...
         contains(lo,'severe') || contains(lo,'no dr') || ...
         contains(lo,'hemorrhag') || contains(lo,'exudat') || ...
         contains(lo,'aneurysm') || contains(lo,'microaneurysm');
end

function level = parseLevel(s)
    level = -1;
    tk = regexp(s, '[Ll]evel\s*([0-4])', 'tokens', 'once');
    if ~isempty(tk), level = str2double(tk{1}); end

    tk = regexp(s, '[Gg]rade\s*([0-4])', 'tokens', 'once');
    if level < 0 && ~isempty(tk), level = str2double(tk{1}); end

    if level < 0 && ~isempty(regexp(strtrim(s), '^[0-4]$', 'once'))
        level = str2double(strtrim(s));
    end

    lo = lower(s);
    if level < 0
        if contains(lo,'proliferative') || contains(lo,'pdr')
            level = 4;
        elseif contains(lo,'severe')
            level = 3;
        elseif contains(lo,'moderate')
            level = 2;
        elseif contains(lo,'mild')
            level = 1;
        elseif contains(lo,'no dr') || contains(lo,'none')
            level = 0;
        end
    end
    if level >= 0, level = max(0, min(4, level)); end
end

function ev = evidenceLine(diagStr)
    ev = '';
    lo = lower(diagStr);
    c = @(pat) regexp(lo, ['(\d+)\s*' pat], 'tokens', 'once');

    h = c('hemorrhag'); x = c('exudat'); m = c('microaneurysm');
    if isempty(h) && isempty(x) && isempty(m), return; end

    parts = {};
    if ~isempty(h), parts{end+1} = sprintf('%s bleeding spots (hemorrhages)', h{1}); end
    if ~isempty(x), parts{end+1} = sprintf('%s fat leaks (exudates)', x{1}); end
    if ~isempty(m), parts{end+1} = sprintf('%s swollen tiny dots (microaneurysms)', m{1}); end
    ev = strjoin(parts, ', ');
end

function html = buildAdviceHtml(diagStr, question)
    level = parseLevel(diagStr);
    if level == -1
        html = ['What level is your diabetic retinopathy? ' ...
            'Please type your screening level (0 to 4) ' ...
            'so I can give you the exact advice.'];
        return;
    end

    ev = evidenceLine(diagStr);
    switch level
        case 0
            title = 'Your eyes are safe right now (Level 0)';
            what = ['Good news. The scan did not find any damage ' ...
                'from diabetes in your eye. Your eyes are fine for now. ' ...
                'Continue regular monitoring.'];
            urWord = 'NO HURRY';
            urText = 'No urgent visit needed. Check your eyes again once a year.';
            urCol = '#4ade80';
            pre = {'Keep blood sugar in safe range', 'Keep blood pressure under 130/80', 'Get an eye test every year'};
            life = {'Avoid sugary drinks and sweets', 'Walk briskly for 30 minutes, 5 days a week'};
            treat = {'No eye treatment needed now. Focus on sugar and blood pressure control.'};
            dang = dangerList(0);
        case 1
            title = 'Early microvascular changes detected (Level 1)';
            what = ['A tiny change has started in the small blood vessels of your eye. ' ...
                'Eyesight is usually preserved. Strict control prevents progression.'];
            urWord = 'NO HURRY, BUT DO NOT SKIP';
            urText = 'Check your eyes again in 6 to 12 months.';
            urCol = '#fbbf24';
            pre = {'Get an eye test again in 6 to 12 months', 'Control blood sugar strictly'};
            life = {'Eat more fiber (vegetables, dal, whole grains)', 'Walk daily; do not smoke'};
            treat = {'No laser or injections needed yet. Primary therapy is glycemic control.'};
            dang = dangerList(1);
        case 2
            title = 'Moderate Retinal Damage (Level 2)';
            what = ['The scan found bleeding spots, fat leaks, or swollen dots. ' ...
                'Diabetes has begun damaging structural capillaries.'];
            urWord = 'SEE AN EYE DOCTOR WITHIN 2-3 WEEKS';
            urText = 'Schedule a comprehensive dilated fundus examination promptly.';
            urCol = '#fbbf24';
            pre = {'Consult an ophthalmologist within 2-3 weeks', 'Strict blood pressure (<130/80) and HbA1c control'};
            life = {'Avoid sudden glycemic spikes', 'Avoid strenuous Valsalva straining'};
            treat = {'Anti-VEGF injections may be indicated if macular edema develops.'};
            dang = dangerList(2);
        case 3
            title = 'Serious eye damage (Level 3 - Severe NPDR)';
            what = ['Capillary non-perfusion has spread widely across retinal quadrants. ' ...
                'High risk of conversion to proliferative disease.'];
            urWord = 'SEE AN EYE DOCTOR THIS WEEK';
            urText = 'Urgent retinal specialist consultation required.';
            urCol = '#f87171';
            pre = {'See a retinal specialist within 1 week', 'Strict avoidance of heavy lifting'};
            life = {'Complete cessation of smoking and tobacco', 'Avoid vigorous straining'};
            treat = {'Panretinal Photocoagulation (PRP) laser or anti-VEGF injections may be scheduled.'};
            dang = dangerList(3);
        case 4
            title = 'Very serious eye damage - EMERGENCY (Level 4 - PDR)';
            what = ['Fragile neovascular vessels are growing. ' ...
                'Risk of vitreous hemorrhage or tractional retinal detachment.'];
            urWord = 'IMMEDIATE SPECIALIST REFERRAL REQUIRED';
            urText = 'Go to an eye hospital today. Do not delay.';
            urCol = '#f87171';
            pre = {'Go to an ophthalmologist today', 'Avoid all straining and head-down postures'};
            life = {'If vision suddenly darkens, remain upright and seek emergency eye care'};
            treat = {'Urgent PRP laser, anti-VEGF injections, or vitrectomy surgery required.'};
            dang = dangerList(4);
    end

    evHtml = '';
    if ~isempty(ev)
        evHtml = ['<section><strong>Biomarker Breakdown</strong><p>' ev '.</p></section>'];
    end

    chatLine = '';
    if ~isempty(question)
        chatLine = ['<section><strong>Clinical Context</strong><p>' simpleAnswer(question, level) '</p></section>'];
    end

    html = [ ...
        '<div class="advice-card">' ...
        '<section><strong>What this means</strong><p>' title ' - ' what '</p></section>' ...
        evHtml ...
        '<section><strong>Triage Action Plan</strong>' ...
        '<div style="background:rgba(248,113,113,0.10); border:1px solid ' urCol '; color:' urCol '; padding:10px 14px; border-radius:12px; font-weight:700; font-size:14px; margin-top:8px;">' ...
        urWord ' - ' urText '</div></section>' ...
        '<section><strong>Daily Guidelines</strong>' htmlList(pre) '</section>' ...
        '<section><strong>Lifestyle & Warnings</strong>' htmlList(life) '</section>' ...
        '<section><strong>Therapeutic Options</strong>' htmlList(treat) '</section>' ...
        '<section><strong>Emergency Warning Signs</strong>' htmlList(dang) '</section>' ...
        chatLine ...
        '<small>This advice is from DristhiSetu screening (Level ' num2str(level) '). Not a final clinical diagnosis. Please present this report to an ophthalmologist.</small>' ...
        '</div>' ...
    ];
end

function R = dangerList(tier)
    base = {'Sudden darkness or blurring in one eye', ...
            'A sudden shower of black spots or floaters', ...
            'Flashes of light in peripheral vision', ...
            'A dark shadow or curtain falling across vision'};
    if tier <= 1
        R = base;
    elseif tier == 2
        R = [base, {'Progressive focal blurring'}];
    else
        R = [base, {'Progressive vision loss', 'Sudden severe eye pain or redness'}];
    end
end

function ul = htmlList(items)
    ul = '<ul>';
    for i = 1:numel(items)
        ul = [ul '<li>' items{i} '</li>'];
    end
    ul = [ul '</ul>'];
end

function ans = simpleAnswer(q, level)
    if nargin < 2, level = -1; end
    q = lower(char(string(q)));

    if contains(q,'smoke') || contains(q,'tobacco')
        ans = 'Smoking causes severe retinal hypoxia and accelerates microvascular occlusions. Immediate cessation is essential.';
    elseif contains(q,'phone') || contains(q,'screen') || contains(q,'computer')
        ans = 'Screen usage causes dry eye and digital strain, but does not structurally worsen diabetic retinopathy.';
    elseif contains(q,'heavy') || contains(q,'lift')
        if level >= 3
            ans = 'Avoid heavy lifting. Valsalva maneuvers spike intraocular venous pressure and can rupture fragile neovascular capillaries.';
        else
            ans = 'Light to moderate exercise is beneficial. Avoid extreme straining if severe disease develops.';
        end
    elseif contains(q,'hba1c') || contains(q,'blood sugar')
        ans = 'Target an HbA1c strictly below 7.0%, with fasting blood glucose between 80-120 mg/dL.';
    elseif contains(q,'blood pressure') || contains(q,'bp')
        ans = 'Maintain systolic and diastolic pressure below 130/80 mmHg to prevent capillary shear stress.';
    else
        ans = 'Strict control of glucose and blood pressure, routine retinal exams, and adherence to medical therapy are key to preventing vision loss.';
    end
end