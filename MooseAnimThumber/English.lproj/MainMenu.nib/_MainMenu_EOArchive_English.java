// _MainMenu_EOArchive_English.java
// Generated by EnterpriseObjects palette at Samstag, 25. Februar 2006 14:44 Uhr Europe/Berlin

import com.webobjects.eoapplication.*;
import com.webobjects.eocontrol.*;
import com.webobjects.eointerface.*;
import com.webobjects.eointerface.swing.*;
import com.webobjects.foundation.*;
import java.awt.*;
import javax.swing.*;
import javax.swing.border.*;
import javax.swing.table.*;
import javax.swing.text.*;

public class _MainMenu_EOArchive_English extends com.webobjects.eoapplication.EOArchive {
    MooseAnimThumberAppDelegate _mooseAnimThumberAppDelegate0;
    com.webobjects.eointerface.swing.EOFrame _eoFrame0;
    com.webobjects.eointerface.swing.EOImageView _nsImageView0;
    com.webobjects.eointerface.swing.EOView _nsProgressIndicator0;
    javax.swing.JPanel _nsView0;

    public _MainMenu_EOArchive_English(Object owner, NSDisposableRegistry registry) {
        super(owner, registry);
    }

    protected void _construct() {
        Object owner = _owner();
        EOArchive._ObjectInstantiationDelegate delegate = (owner instanceof EOArchive._ObjectInstantiationDelegate) ? (EOArchive._ObjectInstantiationDelegate)owner : null;
        Object replacement;

        super._construct();


        if ((delegate != null) && ((replacement = delegate.objectForOutletPath(this, "delegate.preview")) != null)) {
            _nsImageView0 = (replacement == EOArchive._ObjectInstantiationDelegate.NullObject) ? null : (com.webobjects.eointerface.swing.EOImageView)replacement;
            _replacedObjects.setObjectForKey(replacement, "_nsImageView0");
        } else {
            _nsImageView0 = (com.webobjects.eointerface.swing.EOImageView)_registered(new com.webobjects.eointerface.swing.EOImageView(), "");
        }

        if ((delegate != null) && ((replacement = delegate.objectForOutletPath(this, "delegate")) != null)) {
            _mooseAnimThumberAppDelegate0 = (replacement == EOArchive._ObjectInstantiationDelegate.NullObject) ? null : (MooseAnimThumberAppDelegate)replacement;
            _replacedObjects.setObjectForKey(replacement, "_mooseAnimThumberAppDelegate0");
        } else {
            _mooseAnimThumberAppDelegate0 = (MooseAnimThumberAppDelegate)_registered(new MooseAnimThumberAppDelegate(), "MooseAnimThumberAppDelegate");
        }

        if ((delegate != null) && ((replacement = delegate.objectForOutletPath(this, "delegate.progress")) != null)) {
            _nsProgressIndicator0 = (replacement == EOArchive._ObjectInstantiationDelegate.NullObject) ? null : (com.webobjects.eointerface.swing.EOView)replacement;
            _replacedObjects.setObjectForKey(replacement, "_nsProgressIndicator0");
        } else {
            _nsProgressIndicator0 = (com.webobjects.eointerface.swing.EOView)_registered(new com.webobjects.eointerface.swing.EOView(), "1");
        }

        _eoFrame0 = (com.webobjects.eointerface.swing.EOFrame)_registered(new com.webobjects.eointerface.swing.EOFrame(), "Window");
        _nsView0 = (JPanel)_eoFrame0.getContentPane();
    }

    protected void _awaken() {
        super._awaken();
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(_owner(), "unhideAllApplications", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(_owner(), "hide", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(_owner(), "hideOtherApplications", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(_owner(), "orderFrontStandardAboutPanel", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(_owner(), "terminate", ), ""));

        if (_replacedObjects.objectForKey("_mooseAnimThumberAppDelegate0") == null) {
            _connect(_owner(), _mooseAnimThumberAppDelegate0, "delegate");
        }
    }

    protected void _init() {
        super._init();
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performFindPanelAction", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "runPageLayout", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "pasteAsPlainText", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "checkSpelling", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "clearRecentDocuments", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "cut", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "redo", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "print", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performFindPanelAction", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "paste", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "showGuessPanel", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "selectAll", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performZoom", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "undo", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performClose", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "showHelp", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "centerSelectionInVisibleArea", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "copy", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "delete", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performFindPanelAction", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "toggleContinuousSpellChecking", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performFindPanelAction", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "performMiniaturize", ), ""));
        .addActionListener((com.webobjects.eointerface.swing.EOControlActionAdapter)_registered(new com.webobjects.eointerface.swing.EOControlActionAdapter(null, "arrangeInFront", ), ""));

        if (_replacedObjects.objectForKey("_mooseAnimThumberAppDelegate0") == null) {
            _connect(_mooseAnimThumberAppDelegate0, _nsImageView0, "preview");
        }

        if (_replacedObjects.objectForKey("_mooseAnimThumberAppDelegate0") == null) {
            _connect(_mooseAnimThumberAppDelegate0, _nsProgressIndicator0, "progress");
        }

        if (!(_nsView0.getLayout() instanceof EOViewLayout)) { _nsView0.setLayout(new EOViewLayout()); }
        _nsProgressIndicator0.setSize(396, 20);
        _nsProgressIndicator0.setLocation(11, 150);
        ((EOViewLayout)_nsView0.getLayout()).setAutosizingMask(_nsProgressIndicator0, EOViewLayout.MinYMargin);
        _nsView0.add(_nsProgressIndicator0);
        _nsImageView0.setSize(134, 134);
        _nsImageView0.setLocation(142, 11);
        ((EOViewLayout)_nsView0.getLayout()).setAutosizingMask(_nsImageView0, EOViewLayout.MinXMargin | EOViewLayout.MaxXMargin | EOViewLayout.MaxYMargin);
        _nsView0.add(_nsImageView0);
        _nsView0.setSize(418, 180);
        _eoFrame0.setTitle("MooseAnimThumber Progress");
        _eoFrame0.setLocation(227, 607);
        _eoFrame0.setSize(418, 180);
    }
}
