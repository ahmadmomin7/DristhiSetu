% member5_app_frontend/generate_clinical_pdf.m
function pdfPath = generate_clinical_pdf(reportData)
    % GENERATE_CLINICAL_PDF High-Precision Standard A4 PDF Generator
    
    timestampStr = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    fileIdStr    = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    
    [~, baseName, ~] = fileparts(reportData.imgName);
    cleanBaseName = regexprep(baseName, '[^a-zA-Z0-9_-]', '_');
    pdfFilename = sprintf('DristhiSetu_Report_%s_%s.pdf', cleanBaseName, fileIdStr);
    
    userDir = char(java.lang.System.getProperty('user.home'));
    outFolder = fullfile(userDir, 'Documents', 'DristhiSetu_Reports');
    if ~isfolder(outFolder), mkdir(outFolder); end
    pdfPath = fullfile(outFolder, pdfFilename);
    
    % Strict A4 Canvas Setup: 8.27 x 11.69 inches
    f = figure('Units', 'inches', 'Position', [1, 1, 8.27, 11.69], ...
               'PaperUnits', 'inches', 'PaperPosition', [0, 0, 8.27, 11.69], ...
               'PaperSize', [8.27, 11.69], 'Color', [1 1 1], ...
               'Visible', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
           
    % -------------------------------------------------------------------------
    % 1. TOP HEADER BANNER (Single-line, no text wrapping)
    % -------------------------------------------------------------------------
    annotation(f, 'rectangle', [0.05, 0.932, 0.90, 0.046], ...
               'FaceColor', [0.07, 0.11, 0.18], 'EdgeColor', 'none');
           
    % Widened to 0.65 to fit title comfortably on a single line
    annotation(f, 'textbox', [0.065, 0.936, 0.65, 0.036], ...
               'String', 'DRISTHISETU AI  |  CLINICAL TRIAGE REPORT', ...
               'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.22, 0.74, 0.97], ...
               'Interpreter', 'none', 'LineStyle', 'none');
           
    annotation(f, 'textbox', [0.65, 0.936, 0.28, 0.036], ...
               'String', sprintf('Date: %s', timestampStr), ...
               'FontSize', 9, 'Color', [0.80, 0.86, 0.92], ...
               'HorizontalAlignment', 'right', 'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 2. SCAN & METRIC STRIP
    % -------------------------------------------------------------------------
    annotation(f, 'rectangle', [0.05, 0.888, 0.90, 0.036], ...
               'FaceColor', [0.94, 0.96, 0.99], 'EdgeColor', [0.80, 0.85, 0.92], 'LineWidth', 0.8);
    metaStr = sprintf('Scan Asset: %s    |    ResNet-18 Conf: %.1f%%    |    Quality: PASSED (Sharp: %.1f, Cont: %.2f)', ...
                      reportData.imgName, reportData.cnnConf, reportData.sharpVal, reportData.contVal);
    annotation(f, 'textbox', [0.065, 0.890, 0.87, 0.030], 'String', metaStr, ...
               'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.15, 0.20, 0.28], ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 3. DIAGNOSIS & ACTION CALLOUT BOX
    % -------------------------------------------------------------------------
    if contains(lower(reportData.refTag), 'emergency')
        boxBg = [0.99, 0.92, 0.92]; boxEdge = [0.88, 0.20, 0.20]; boxTxt = [0.75, 0.05, 0.05];
    elseif contains(lower(reportData.refTag), 'yes')
        boxBg = [0.99, 0.96, 0.88]; boxEdge = [0.90, 0.60, 0.10]; boxTxt = [0.70, 0.40, 0.05];
    else
        boxBg = [0.92, 0.98, 0.92]; boxEdge = [0.20, 0.70, 0.30]; boxTxt = [0.10, 0.50, 0.20];
    end
    annotation(f, 'rectangle', [0.05, 0.825, 0.90, 0.053], ...
               'FaceColor', boxBg, 'EdgeColor', boxEdge, 'LineWidth', 1.2);
    annotation(f, 'textbox', [0.07, 0.849, 0.86, 0.024], ...
               'String', sprintf('DIAGNOSTIC STAGING:  %s', upper(reportData.gradeStr)), ...
               'FontSize', 11, 'FontWeight', 'bold', 'Color', boxTxt, ...
               'Interpreter', 'none', 'LineStyle', 'none');
    annotation(f, 'textbox', [0.07, 0.828, 0.86, 0.022], ...
               'String', sprintf('REFERRAL DECISION:  %s', upper(reportData.refTag)), ...
               'FontSize', 10, 'FontWeight', 'bold', 'Color', boxTxt, ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 4. SECTION 1: PRIMARY DUAL FUNDUS SCANS
    % -------------------------------------------------------------------------
    annotation(f, 'textbox', [0.05, 0.795, 0.90, 0.022], ...
               'String', '1. PRIMARY RETINAL EVALUATION (INPUT VS. MULTI-BIOMARKER OVERLAY)', ...
               'FontSize', 9.5, 'FontWeight', 'bold', 'Color', [0.10, 0.15, 0.22], ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % Left: Raw Scan
    ax1 = axes(f, 'Position', [0.12, 0.615, 0.33, 0.17]);
    imshow(reportData.rawImg, 'Parent', ax1);
    axis(ax1, 'image');
    annotation(f, 'textbox', [0.12, 0.590, 0.33, 0.022], ...
               'String', 'Original Input Fundus', 'FontSize', 8.5, 'FontWeight', 'bold', ...
               'Color', [0.25, 0.30, 0.35], 'HorizontalAlignment', 'center', ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % Right: Overlay Scan
    ax2 = axes(f, 'Position', [0.55, 0.615, 0.33, 0.17]);
    imshow(reportData.overlayImg, 'Parent', ax2);
    axis(ax2, 'image');
    annotation(f, 'textbox', [0.55, 0.590, 0.33, 0.022], ...
               'String', 'Multi-Biomarker Overlay', 'FontSize', 8.5, 'FontWeight', 'bold', ...
               'Color', [0.25, 0.30, 0.35], 'HorizontalAlignment', 'center', ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 5. SECTION 2: HIGH-CONTRAST LESION BREAKDOWN
    % -------------------------------------------------------------------------
    annotation(f, 'textbox', [0.05, 0.555, 0.90, 0.022], ...
               'String', '2. EXTRACTED MORPHOLOGICAL LESION BREAKDOWN', ...
               'FontSize', 9.5, 'FontWeight', 'bold', 'Color', [0.10, 0.15, 0.22], ...
               'Interpreter', 'none', 'LineStyle', 'none');

    % Exudates
    bx1 = axes(f, 'Position', [0.05, 0.448, 0.20, 0.098]);
    imshow(reportData.imgEx, 'Parent', bx1);
    axis(bx1, 'image');
    annotation(f, 'textbox', [0.05, 0.424, 0.20, 0.020], ...
               'String', sprintf('Exudates (%d)', reportData.numEx), ...
               'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.65, 0.45, 0.05], ...
               'HorizontalAlignment', 'center', 'Interpreter', 'none', 'LineStyle', 'none');

    % Microaneurysms
    bx2 = axes(f, 'Position', [0.28, 0.448, 0.20, 0.098]);
    imshow(reportData.imgMA, 'Parent', bx2);
    axis(bx2, 'image');
    annotation(f, 'textbox', [0.28, 0.424, 0.20, 0.020], ...
               'String', sprintf('Microaneurysms (%d)', reportData.numMA), ...
               'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.80, 0.15, 0.15], ...
               'HorizontalAlignment', 'center', 'Interpreter', 'none', 'LineStyle', 'none');

    % Hemorrhages
    bx3 = axes(f, 'Position', [0.51, 0.448, 0.20, 0.098]);
    imshow(reportData.imgHem, 'Parent', bx3);
    axis(bx3, 'image');
    annotation(f, 'textbox', [0.51, 0.424, 0.20, 0.020], ...
               'String', sprintf('Hemorrhages (%d)', reportData.numHem), ...
               'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.70, 0.05, 0.35], ...
               'HorizontalAlignment', 'center', 'Interpreter', 'none', 'LineStyle', 'none');

    % Fovea
    bx4 = axes(f, 'Position', [0.74, 0.448, 0.20, 0.098]);
    imshow(reportData.imgFov, 'Parent', bx4);
    axis(bx4, 'image');
    annotation(f, 'textbox', [0.74, 0.424, 0.20, 0.020], ...
               'String', sprintf('Foveal Threat: %s', reportData.foveaStr), ...
               'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.05, 0.45, 0.85], ...
               'HorizontalAlignment', 'center', 'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 6. SECTION 3: STRUCTURED CLINICAL GUIDANCE
    % -------------------------------------------------------------------------
    annotation(f, 'textbox', [0.05, 0.395, 0.90, 0.022], ...
               'String', '3. CLINICAL TRIAGE RECOMMENDATIONS & ACTION PLAN', ...
               'FontSize', 9.5, 'FontWeight', 'bold', 'Color', [0.10, 0.15, 0.22], ...
               'Interpreter', 'none', 'LineStyle', 'none');

    bulletList = formatStructuredPlan(reportData.gradeStr, reportData.refTag, ...
                                      reportData.numEx, reportData.numMA, reportData.numHem, ...
                                      reportData.foveaStr, reportData.isNeovasc);

    annotation(f, 'rectangle', [0.05, 0.075, 0.90, 0.315], ...
               'FaceColor', [0.98, 0.99, 1.0], 'EdgeColor', [0.82, 0.86, 0.92], 'LineWidth', 0.8);
    annotation(f, 'textbox', [0.065, 0.082, 0.87, 0.300], ...
               'String', bulletList, 'FontSize', 8.5, 'LineStyle', 'none', ...
               'Interpreter', 'none', 'Color', [0.15, 0.20, 0.25]);

    % -------------------------------------------------------------------------
    % 7. FOOTER DISCLAIMER
    % -------------------------------------------------------------------------
    annotation(f, 'textbox', [0.05, 0.020, 0.90, 0.040], ...
               'String', 'IMPORTANT NOTICE: DristhiSetu AI is an assistive decision-support tool. It does not replace definitive clinical examination with dilated ophthalmoscopy or optical coherence tomography (OCT) by a certified retina specialist.', ...
               'FontSize', 7, 'FontAngle', 'italic', 'Color', [0.45, 0.50, 0.55], ...
               'HorizontalAlignment', 'center', 'Interpreter', 'none', 'LineStyle', 'none');

    % -------------------------------------------------------------------------
    % 8. HIGH-RES RENDER
    % -------------------------------------------------------------------------
    drawnow;
    exportgraphics(f, pdfPath, 'ContentType', 'image', 'Resolution', 300);
    close(f);
    
    if ispc
        winopen(pdfPath);
    end
end

function bulletList = formatStructuredPlan(gradeStr, refTag, nEx, nMA, nHem, fovStr, isNeo)
    bulletList = {};
    bulletList{end+1} = sprintf('• DIAGNOSTIC CLASSIFICATION: Staged at %s [%s].', upper(gradeStr), upper(refTag));
    bulletList{end+1} = ' ';
    bulletList{end+1} = '• KEY BIOMARKER FINDINGS:';
    bulletList{end+1} = sprintf('    - Hard Exudates: %d detected (lipid and protein fluid leakage).', nEx);
    bulletList{end+1} = sprintf('    - Microaneurysms: %d detected (localized capillary outpouchings).', nMA);
    bulletList{end+1} = sprintf('    - Hemorrhages: %d detected (intraretinal micro-bleeds).', nHem);
    bulletList{end+1} = sprintf('    - Foveal / Central Macula Risk: %s.', fovStr);
    if isNeo
        bulletList{end+1} = '    - Neovascularization: HIGH RISK (abnormal fragile vessel fronds detected).';
    end
    bulletList{end+1} = ' ';
    bulletList{end+1} = '• CLINICAL ACTION PLAN:';
    if contains(lower(refTag), 'emergency')
        bulletList{end+1} = '    - Immediate Specialist Referral: Consult an ophthalmologist or retina hospital TODAY.';
        bulletList{end+1} = '    - Activity Restriction: Strictly avoid heavy lifting, straining, and inverted postures.';
        bulletList{end+1} = '    - Therapeutic Options: Urgent PRP laser photocoagulation or anti-VEGF injections.';
    elseif contains(lower(refTag), 'urgent')
        bulletList{end+1} = '    - Specialist Referral: Schedule an eye specialist examination within this week.';
        bulletList{end+1} = '    - Glycemic Targets: Maintain strict control (HbA1c < 7.0%, BP < 130/80 mmHg).';
        bulletList{end+1} = '    - Precaution: Avoid high-impact exercise that spikes intraocular pressure.';
    else
        bulletList{end+1} = '    - Routine Follow-up: Schedule annual comprehensive dilated fundus examination.';
        bulletList{end+1} = '    - Preventative Care: Maintain healthy blood glucose, lipid levels, and blood pressure.';
    end
    bulletList{end+1} = ' ';
    bulletList{end+1} = '• EMERGENCY WARNING SIGNS (SEEK IMMEDIATE ER EVALUATION):';
    bulletList{end+1} = '    - Sudden darkness or complete loss of vision in either eye.';
    bulletList{end+1} = '    - Rapid shower of black spots, dense floaters, or persistent peripheral flashes.';
    bulletList{end+1} = '    - A dark curtain or veil obstructing any portion of the visual field.';
end