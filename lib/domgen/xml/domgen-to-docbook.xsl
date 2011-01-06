<xsl:stylesheet version="2.0"
                xmlns="http://docbook.org/ns/docbook"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:template match="/data-module">
    <article version="5.0">
      <info><title><xsl:value-of select="@name"/></title></info>
      <xsl:apply-templates select="object-type"/>
    </article>
  </xsl:template>

  <xsl:template match="object-type">
    <table frame="all">
      <title><xsl:value-of select="@name"/></title>
      <tgroup cols="8" align="left" colsep="1" rowsep="1">
        <colspec colname="attribute" colwidth="1.6in"/>
        <colspec colname="description"/>
        <colspec colname="sql-type" colwidth="1.2in"/>
        <colspec colname="generated" colwidth="0.4in"/>
        <colspec colname="immutable" colwidth="0.4in"/>
        <colspec colname="blank" colwidth="0.4in"/>
        <colspec colname="nullable" colwidth="0.4in"/>
        <colspec colname="unique" colwidth="0.4in"/>
        <thead>
          <row>
            <entry>Attribute</entry>
            <entry>Description</entry>
            <entry>Sql Type</entry>
            <entry><superscript>Gener- ated</superscript></entry>
            <entry><superscript>Immut- able</superscript></entry>
            <entry><superscript>Allow blank</superscript></entry>
            <entry><superscript>Nullable</superscript></entry>
            <entry><superscript>Unique</superscript></entry>
          </row>
        </thead>
        <tbody>
          <xsl:apply-templates select="attributes/attribute"/>
        </tbody>
      </tgroup>
    </table>
  </xsl:template>

  <xsl:template match="attribute">
    <row>
      <entry><xsl:value-of select="@name"/></entry>
      <entry><xsl:value-of select="tags/Description/text()"/></entry>
      <entry><xsl:value-of select="persistent/@sql-type"/></entry>
      <entry><xsl:value-of select="@generated"/></entry>
      <entry><xsl:value-of select="@immutable"/></entry>
      <entry><xsl:value-of select="@allow-blank"/></entry>
      <entry><xsl:value-of select="@nullable"/></entry>
      <entry><xsl:value-of select="@unique"/></entry>
    </row>
  </xsl:template>
</xsl:stylesheet>
