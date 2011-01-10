<xsl:stylesheet version="2.0"
                xmlns="http://docbook.org/ns/docbook"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="/repository">
    <article version="5.0">
      <info>
        <title>
          <xsl:value-of select="@name"/>
        </title>
      </info>
      <xsl:apply-templates select="data-module"/>
    </article>
  </xsl:template>

  <xsl:template match="data-module">
    <section>
      <title>
        <xsl:value-of select="@name"/>
      </title>
      <xsl:apply-templates select="object-type"/>
    </section>
  </xsl:template>

  <xsl:template name="rotate-cell">
    <xsl:processing-instruction name="dbfo">
      <xsl:text>orientation="90"</xsl:text>
    </xsl:processing-instruction>
    <xsl:processing-instruction name="dbfo">
      <xsl:text>rotated-width="1in"</xsl:text>
    </xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="object-type">
    <section>
      <title>
        <xsl:value-of select="@name"/>
      </title>
      <xsl:apply-templates select="tags"/>
      <table frame="all">
        <xsl:processing-instruction name="dbfo">
          <xsl:text>keep-together="always"</xsl:text>
        </xsl:processing-instruction>
        <title>Attributes</title>
        <tgroup cols="7" align="left" colsep="1" rowsep="1">
          <colspec colname="attribute" colwidth="1.6in"/>
          <colspec colname="description"/>
          <colspec colname="sql-type" colwidth="1.2in"/>
          <colspec colname="generated" colwidth="0.4in"/>
          <colspec colname="immutable" colwidth="0.4in"/>
          <colspec colname="blank" colwidth="0.4in"/>
          <colspec colname="nullable" colwidth="0.4in"/>
          <thead>
            <row>
              <entry>Attribute</entry>
              <entry>Description</entry>
              <entry>
                <xsl:call-template name="rotate-cell"/>Column Type
              </entry>
              <entry>
                <xsl:call-template name="rotate-cell"/>Generated?
              </entry>
              <entry>
                <xsl:call-template name="rotate-cell"/>Immutable?
              </entry>
              <entry>
                <xsl:call-template name="rotate-cell"/>Allow Blank?
              </entry>
              <entry>
                <xsl:call-template name="rotate-cell"/>Nullable?
              </entry>
            </row>
          </thead>
          <tbody>
            <xsl:apply-templates select="attributes/attribute"/>
          </tbody>
        </tgroup>
      </table>
    </section>
  </xsl:template>

  <xsl:template match="attribute">
    <row>
      <entry>
        <xsl:value-of select="persistent/@column-name"/>
      </entry>
      <entry>
        <xsl:apply-templates select="tags"/>
      </entry>
      <entry>
        <xsl:value-of select="persistent/@sql-type"/>
      </entry>
      <entry>
        <xsl:value-of select="@generated"/>
      </entry>
      <entry>
        <xsl:value-of select="@immutable"/>
      </entry>
      <entry>
        <xsl:value-of select="@allow-blank"/>
      </entry>
      <entry>
        <xsl:value-of select="@nullable"/>
      </entry>
    </row>
  </xsl:template>

  <xsl:template match="tags">
    <xsl:for-each select="Description/*">
      <xsl:copy-of select="."/>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
